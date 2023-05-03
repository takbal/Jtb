#!/bin/bash
#=
exec julia --project=@. --color=yes --startup-file=no "${BASH_SOURCE[0]}" "$@"
=#

#@linter_refs create_sysimage, visit, MethodAnalysis, create_app, SymbolServer, SymbolServerInstance, getstore

# TODO: remove JuliaInterpreter from [release]/exclude for Jtb in mkj.toml

docstring = """
tool to perform usual tasks on a Julia project

    Usage: mkj TASK

Where task is one of:

    works anywhere:

    new           : create a new project (guided: enter package name and location)
    update        : upgrade the 'mk' shared environment that this tool works in. Run it if
                    a new PackageCompiler or MethodAnalysis version was released.

    works inside a package environment only (as determined by 'julia --project=@.'):

    major         : generate a major release
    minor         : generate a minor release
    patch         : generate a patch release
    image         : generate a sysimage of non-dev deps. Run it after adding a new package.
    using         : generate the list for automatic 'using'. Needs 'startup.jl' installed to work.
                    Run it after adding a new package.
    compiled      : generate list of modules that run compiled in debug. Needs startup.jl installed to work.
                    Run it after changing julia version.
    build         : run the build script (deps/build.jl)
    app [fltstd]  : create a standalone app (see PackageCompiler). If fltstd is added, set filter_stdlibs=true
    changelog     : auto-generate changelog (also called by minor/major/patch)
    register reg  : register the package at registry named 'reg'
    add_gitlab    : add a repo on gitlab for the group [gitlab]/group/project
    add_github    : add a public repo on github as {username}/project
    add_gitserver : add a repo at a git server on [git_server]/host
    symbols       : reparse symbols in dependencies (may help if vscode shows missing refs)

    Configuration is stored in the mkj.toml file.

    Generating a release will first check if repo is clean, and the tests run without failure.
    Then it is going to create the changelog, and checks it in.

    See README on how to create local registries.

    The tool runs in its own global environment named "mkj" that is created automatically. Run 'mkj upgrade'
    to upgrade the packages used there.
"""

using Pkg

### globals

# store the project what --project=@. found
project_dir = dirname(Pkg.project().path)
project_name = Pkg.project().name
my_location = dirname(realpath(Base.source_path()))
def_project_location = ENV["JU_WORKSPACE"]
template_location = normpath(my_location, "template")

### switch to our own private environment

Pkg.activate("mkj", shared=true, io=devnull)

using PackageCompiler, MethodAnalysis, SymbolServer

#################################################

"""temporarily switch to this dir; works with the do keyword"""
function with_working_directory(f::Function, path::AbstractString)
	prev_wd = homedir()
	try
		prev_wd = pwd()
    catch
	end
    try
        cd(path)
        f()
    finally
        cd(prev_wd)
    end
end

function get_config(group, field = nothing)
    global project_dir
    mkj_file = joinpath(project_dir, "mkj.toml")
    if isfile(mkj_file)
        config = Pkg.TOML.parsefile(mkj_file)
        if group in keys(config)
            if isnothing(field)
                return config[group]
            else
                if field in keys(config[group])
                    return config[group][field]
                end
            end
        end
    end
    return nothing
end

function set_config(group, field, value)
    global project_dir
    config = Pkg.TOML.parsefile(joinpath(project_dir, "mkj.toml"))
    config[group][field] = value
    open(joinpath(project_dir, "mkj.toml"), "w") do io
        Pkg.TOML.print(io, config)
    end
end

function translate_string(s)
    global template_location
    s = replace(s, "{user}"=>ENV["USER"])
    s = replace(s, "{home}"=>ENV["HOME"])
    s = replace(s, "{template_location}"=>template_location)
    return s
end

"""returns if the current directory's git repo is clean"""
function is_repo_clean()
    output = strip(read(`git status --porcelain`, String))
    return length(output) == 0
end

"""returns if the current directory's git has a remote"""
function is_remote_added()
    output = strip(read(`git remote -v`, String))
    return length(output) != 0
end

"""generates changelog with auto-changelog"""
function generate_changelog()
    # switchting to Python version, must use
    # feat: fix:, feat!:, fix!: docs:  prefixes with optional () scope
    # https://www.conventionalcommits.org/en/v1.0.0/#specification
    run(`auto-changelog`)
    run(`git add CHANGELOG.md`)
end

function generate_new_version(inc_ver_type::AbstractString)

    global project_dir, project_name

    @assert is_repo_clean() "repository is not clean, aborting"
    println("running tests ...")
    Pkg.test()

    print("are you sure to make a new release? [y/N] ")
    if strip(readline()) != "y" exit() end

    # determine current version
    current_version = Pkg.project().version
    @assert !isnothing(current_version)

    # these are not exported functions
    if inc_ver_type == "patch"
        new_version = Base.nextpatch(current_version)
    elseif inc_ver_type == "minor"
        new_version = Base.nextminor(current_version)
    elseif inc_ver_type == "major"
        new_version = Base.nextmajor(current_version)
    end

    println("incremented $current_version to $new_version")

    # change the version number in Project.toml
    change_projectfile_version(Pkg.project().path, new_version)

    println("temporarily removing packages needed only for development ...")
    packages_to_readd = []
    for dp in get_config("release", "exclude")
        if dp in keys(Pkg.project().dependencies)
            println("  removing $dp ...")
            Pkg.rm(dp)
            push!(packages_to_readd, dp)
        end
    end

    try

        # auto-changelog needs the new release tag first to generate an entry for it

        println("tagging release for auto-changelog ...")
        run(`git tag -a $new_version -m "RELEASE $new_version"`)

        println("creating changelog ...")
        generate_changelog()

        println("committing pre-release changes ...")
        # this will not appear in changelog
        run(`git commit -a -m "[AUTO] pre-release $new_version"`)

        println("pushing ...")
        run(`git tag -f -a $new_version -m "RELEASE $new_version"`)
        run(`git push`)
        run(`git push origin $new_version`)

        if !isempty(get_config("local_registry", "name"))
            register_package()
        end

    finally
        
        println("adding back removed development packages ...")
        for dp in packages_to_readd
            Pkg.add(dp)
        end

    end

    println("committing post-release changes ...")
    # this will not appear in changelog
    run(`git commit -a -m "[AUTO] post-release $new_version"`)

    println("pushing ...")
    run(`git push`)

end

function register_package(registry_name = translate_string( get_config("local_registry", "name") ))

    @assert !isempty(registry_name) "registry name must be provided at either mkj.toml, or as mkj register name"

    # create temporary environment
    Pkg.activate(;temp=true, io=devnull)

    if isfile(Pkg.project().path)
        @error "cannot register package in local registry: the temporary shared environment " *
                "already exists. Please delete it at {dirname(Pkg.project().path)}."
    else
        Pkg.add("LocalRegistry")

        @assert isfile(Pkg.project().path) "temporary environment was not created correctly, aborting"

        registry_environment = dirname(Pkg.project().path)

        open(joinpath(registry_environment, "register_package.jl"), "w") do file
            print(file,
                """
                using LocalRegistry
                using Pkg

                project_dir = ARGS[1]
                project_name = ARGS[2]
                registry_name = ARGS[3]

                println("  temporarily adding package to registry environment in dev mode ...")
                Pkg.develop( path = project_dir )

                println("  registering new version from registry environment...")
                register(project_name; registry = registry_name)

                println("  removing package from registry environment ...")
                Pkg.rm( project_name )
                """             
            )
        end

        println("registering new version ...")
        with_working_directory(registry_environment) do
            run(`julia --project=$registry_environment register_package.jl $project_dir $project_name $registry_name`)
        end

        println("pushing registry to remote server ...")
        with_working_directory( normpath(ENV["HOME"], ".julia", "registries", registry_name) ) do
            run(`git push`)
        end

    end

    Pkg.activate(project_dir, io=devnull)        
end

function change_projectfile_version(path::AbstractString, v::VersionNumber)
    projectfile = Pkg.TOML.parsefile(path)
    projectfile["version"] = string(v)
    open(path, "w") do io
        Pkg.TOML.print(io, projectfile)
    end
end

function generate_image()

    global project_dir

    noimage_packages = get_config("image", "exclude")
    image_commands = get_config("image_commands")
    include_packages = get_config("image", "include")

    # this determines which packages to put into the image - not the same as for 'using'
    # as tracked packages are excluded
    to_sysimage = [ pkg.name for (_,pkg) in Pkg.dependencies() if pkg.is_direct_dep &&
                    !(pkg.name in noimage_packages) && !pkg.is_tracking_path ]

    if !isnothing(include_packages)
        append!(to_sysimage, include_packages)
    end

    # create temporary execution file
    pef_fname = joinpath( project_dir, "tmp_pef.jl")
    println( "generating temporary execution file with packages:")
    open(pef_fname, "w") do io
        for p in to_sysimage
            println(io, "using $p")
            println( "  " * p)
        end
        for p in to_sysimage
            if p in keys(image_commands)
                println(io, "$(translate_string(image_commands[p]))")
            end
        end
    end

    println( "generating image ...")

    create_sysimage(Symbol.(to_sysimage); sysimage_path = joinpath(project_dir,
                     "JuliaSysimage.so"), precompile_execution_file = pef_fname )

    cp(joinpath(project_dir, "Manifest.toml"), joinpath(project_dir,
            "Manifest.toml.sysimage"), force = true)
    cp(joinpath(project_dir, "Project.toml"), joinpath(project_dir,
            "Project.toml.sysimage"), force = true)

    rm(pef_fname)

end

function update_compiled()

    all_in_base = []

    visit(Base) do item
        if isa(item, Module)
            push!(all_in_base, string(item))
        end
        return true
    end

    exclude = get_config("compiled", "exclude")
    set_config("compiled", "modules", setdiff(all_in_base, exclude ) )

end

function create_new_project()

    global template_location, project_dir, project_name

    print("new project (package) name: ")
    project_name = strip(readline())
    @assert !isempty(project_name) "you must supply a project name"

    print("parent directory of the project [$def_project_location]: ")
    project_location = strip(readline())
    if isempty(project_location)
        project_location = def_project_location
    end

    project_dir = joinpath(project_location, project_name)
    @assert !ispath(project_dir) "project already exists"

    println("generating template ...")
    Pkg.generate(project_dir)

    if isdir(template_location)
        println("copying additional template files ...")
        run(`cp -a -f -T $template_location $project_dir`)
    end

    # set the new project's initial version to 0.0.0 rather than to the default 0.1.0
    change_projectfile_version(joinpath(project_dir, "Project.toml"), v"0.0.0")

    Pkg.activate(project_dir, io=devnull)

    with_working_directory(project_dir) do

        if isfile("mkj.toml")

            mkj_config = Pkg.TOML.parsefile("mkj.toml")

            println("adding development packages ...")
            for dp in mkj_config["new"]["packages"]
                Pkg.add(dp)
            end

            # remove [new] section
            delete!(mkj_config, "new")
            open("mkj.toml", "w") do io
                Pkg.TOML.print(io, mkj_config)
            end    
            
            update_compiled()
            update_using()

        end

        print("do you need git (must have for all remote setup)? [Y/n] ")
        if strip(readline()) != "n"    
            println("creating git repository ...")
            run(`git init`)
            run(`git add .`)    
            git_added = true    
        else
            git_added = false
        end
    
        if git_added

            if isfile("mkj.toml")

                mkj_config = Pkg.TOML.parsefile("mkj.toml")

                remote_git_server = translate_string(mkj_config["git_server"]["host"])

                if !isempty(remote_git_server)
                    print("set up a local remote at $remote_git_server? [y/N] ")
                    if strip(readline()) == "y"
                        add_gitserver()
                    end
                end

                gitlab_group = mkj_config["gitlab"]["group"]

                if !isempty(gitlab_group)
                    print("add a remote at GitLab group $gitlab_group? [y/N] ")
                    if strip(readline()) == "y"
                        add_gitlab()
                    end
                end

            end

            print("add a public remote at GitHub (gh and jq must work)? [y/N] ")

            if strip(readline()) == "y"
                add_github()
            end

            # this will not appear in changelog
            run(`git commit -a -m "[AUTO] initial check-in"`)

            if is_remote_added()
                run(`git push`)
            end
    
        end

    end

end

function add_gitserver()

    global project_name
    
    mkj_config = Pkg.TOML.parsefile("mkj.toml")
    remote_git_server = translate_string(mkj_config["git_server"]["host"])

    @assert !isempty(remote_git_server) "you need to populate [git_server]/host in mkj.toml"
        
    run(`ssh git@$remote_git_server "new $project_name.git ; exit"`)
    has_remote = is_remote_added()
    if !has_remote
        run(`git remote add origin git@$remote_git_server:$project_name.git`)
    end
    run(`git remote set-url --add --push origin git@$remote_git_server:$project_name.git`)
    if !has_remote
        run(`git push -u origin HEAD`)
    end

    println("set up a repo at $remote_git_server")

end

function add_gitlab()

    global project_name

    mkj_config = Pkg.TOML.parsefile("mkj.toml")
    gitlab_group = mkj_config["gitlab"]["group"]

    @assert !isempty(gitlab_group) "you need to populate [gitlab]/group in mkj.toml"

    run(`glab auth login`)
    run(`glab repo create $project_name --group $gitlab_group`)
    has_remote = is_remote_added()
    if !has_remote
        run(`git remote add origin https://gitlab.com/$gitlab_group/$project_name.git`)
    end
    run(`git remote set-url --add --push origin https://gitlab.com/$gitlab_group/$project_name.git`)
    if !has_remote
        run(`git push -u origin HEAD`)
    end

    println("set up a repo at https://gitlab.com/$gitlab_group/$project_name.git")

end

function add_github()

    global project_name

    run(`gh auth login`)
    run(`gh repo create $project_name --public`)
    username = readchomp(pipeline(`gh api user`, `jq -r '.login'`))
    has_remote = is_remote_added()
    if !has_remote
        run(`git remote add origin https://github.com/$username/$project_name.git`)
    end
    run(`git remote set-url --add --push origin https://github.com/$username/$project_name.git`)
    if !has_remote
        run(`git push -u origin HEAD`)
    end 

    println("set up a repo at https://github.com/$username/$project_name.git")

end

function update_using()

    global project_dir, project_name

    nousing_packages = get_config("using", "exclude")

    to_using = [ pkg.name for (_,pkg) in Pkg.dependencies() if pkg.is_direct_dep &&
                !(pkg.name in nousing_packages) && !pkg.is_tracking_path ]

    # always put Revise first
    revise_idx = findfirst(to_using .== "Revise")
    if !isnothing(revise_idx)
        to_using[revise_idx] = to_using[1]
        to_using[1] = "Revise"
    end

    # put tracked packages last (these will not get compiled into the image)
    append!(to_using, [ pkg.name for (key,pkg) in Pkg.dependencies() if pkg.is_direct_dep &&
                !(pkg.name in nousing_packages) && pkg.is_tracking_path ])

    if !isnothing(project_name)
        push!(to_using, project_name)
    end

    set_config("using", "packages", to_using)

end

function generate_app(filter_stdlibs)
    
    global project_dir

    create_app(project_dir, joinpath(project_dir, "app"); force=true, filter_stdlibs)
    for f in readdir( joinpath(project_dir, "app", "lib"); join = true)
        if isfile(f)
            run(`strip $f`)
        end
    end
    for f in readdir( joinpath(project_dir, "app", "lib", "julia"); join = true)
        if isfile(f)
            run(`strip $f`)
        end
    end
end

function update_mk()
    Pkg.activate("mkj", shared=true, io=devnull)
    Pkg.update()
end

function parse_symbols()
    
    global project_dir

    store = joinpath(ENV["HOME"], ".config/Code/User/globalStorage/julialang.language-julia/symbolstorev5/")

    println("adding symbols to store at $store")

    ssi = SymbolServerInstance("", store)
    getstore(ssi, project_dir)
end

#################### script starts here

if length(ARGS) == 0 || !(ARGS[1] in ["new", "update", "major", "minor", "patch",
                 "image", "using", "compiled", "build", "app", "changelog",
                 "register", "add_gitlab", "add_github", "add_gitserver", "symbols"])

    println("Unknown task specified.")
    println()
    println(docstring)
    exit()

end

if ARGS[1] == "new"
    create_new_project()

elseif ARGS[1] == "update"
    update_mk()

else

    with_working_directory(project_dir) do

        # this will keep PackageCompiler still available from 'mk'
        Pkg.activate(project_dir, io=devnull)

        # this may fail later as this field is undocumented. Perhaps it can be
        # switched to a condition to be in a non-shared environment? (test path string)
        @assert Pkg.project().ispackage "you are not in a package environment"

        if ARGS[1] in ["major", "minor", "patch" ]
            generate_new_version(ARGS[1])
        elseif ARGS[1] == "image"
            generate_image()
        elseif ARGS[1] == "using"
            update_using()
        elseif ARGS[1] == "compiled"
            update_compiled()
        elseif ARGS[1] == "build"
            Pkg.build(verbose = true)
        elseif ARGS[1] == "app"
            generate_app(length(ARGS) > 1 && ARGS[2] == "fltstd")
        elseif ARGS[1] == "changelog"
            generate_changelog()
        elseif ARGS[1] == "register"
            @assert length(ARGS) >= 2 "you need to specify the registry name (the first string from ]registry status)"
            register_package(ARGS[2])
        elseif ARGS[1] == "add_gitlab"
            add_gitlab()
        elseif ARGS[1] == "add_github"
            add_github()
        elseif ARGS[1] == "add_gitserver"
            add_gitserver()
        elseif ARGS[1] == "symbols"
            parse_symbols()
        else
            error("you should not get here")
        end

    end
end
