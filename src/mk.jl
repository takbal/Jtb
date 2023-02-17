#!/bin/bash
#=
exec julia --project=@. --color=yes --startup-file=no "${BASH_SOURCE[0]}" "$@"
=#

#@linter_refs create_sysimage, visit, MethodAnalysis, create_app

docstring = """
tool to perform usual tasks on a Julia project

    Usage: mk TASK

Where task is one of:

    works anywhere:

    new           : create a new project (guided: enter package name and location)
    env           : create a new shared environment (guided: enter environment name)
    compiled      : generate list of Base modules that should compile for debugging

    affects the environment:

    image         : generate the sysimage of non-dev deps, and a default using.txt if not found
    addev         : add the auto development packages to the current environment
    using         : overwrite the using.txt file with the default

    works only in a package environment:

    major         : generate a major release
    minor         : generate a minor release
    patch         : generate a patch release
    changelog     : auto-generate changelog (also called by minor/major/patch)
    build         : run the build script (deps/build.jl)
    app [fltstd]  : create a standalone app (see PackageCompiler). If fltstd is added, set filter_stdlibs=true

    The affected environment is the one selected by --project=@.

    Generating a release will first check if repo is clean, and the tests run without failure.
    Then it is going to create the changelog, and checks it in.

    The tool runs in its own global environment named "mk" that needs to have PackageCompiler and
    MethodAnalysis installed.
"""

using Pkg

# store the @. exploring result
project_dir = dirname(Pkg.project().path)
project_name = Pkg.project().name

# switch to our own private environment
Pkg.activate("mk", shared=true)

using PackageCompiler, MethodAnalysis

################### static params start

# these are the packages that, if found, will got temporarily removed for making a release,
# so they are never going to be a dependency. Add packages here that are only needed during
# development.
development_packages = ["Revise", "Atom", "Juno", "MethodAnalysis", "JuliaInterpreter",
    "StaticLint", "PkgAuthentication", "CodeTools", "Traceur", "BenchmarkTools", "JET", "ProfileView"]

# automatically add these packages to a new project
auto_packages = ["Revise", "JuliaInterpreter", "BenchmarkTools"] #  + "Atom", "Juno" if Atom is used

# do not add these packages to the default using.txt (this does not exclude adding it to the image)
nousing_packages=["Atom"]

# never add these packages to the image
noimage_packages = []

# additional commands to execute before image generation if a package is present. This can
# massively speed up first run of JIT-ted commands.
image_commands = Dict(
    "PlotlyJS" => "display(plot([1],[1]))",
    "JLD2" => "load(\"/home/takbal/workspace/Jtb/data/compressed.jld2\"); "*
              "load(\"/home/takbal/workspace/Jtb/data/uncompressed.jld2\")",
    "ArgParse" => """
                  s = ArgParseSettings()
                  @add_arg_table! s begin
                      "--opt1"
                          help = "an option with an argument"
                      "--opt2", "-o"
                          help = "another option with an argument"
                          arg_type = Int
                          default = 0
                      "--flag1"
                          help = "an option without argument, i.e. a flag"
                          action = :store_true
                      "arg1"
                          help = "a positional argument"
                  end
                  parse_args(s)
                  """,
    "Optim" => """
               f(x) = (1.0 - x[1])^2 + 100.0 * (x[2] - x[1]^2)^2
               optimize(f, [0. 0.], LBFGS())
               """
)

# this points to a Julia environment where the registry is going to be updated from. It must
# have LocalRegistry added as a dependency, and a file named register_package.jl in its root,
# with the following content:
#
#   using LocalRegistry
#   using Pkg
#
#   project_dir = ARGS[1]
#   project_name = ARGS[2]
#   registry_name = ARGS[3]
#
#   println("  temporarily adding package to registry environment in dev mode ...")
#   Pkg.develop( path = project_dir )
#
#   println("  registering new version from registry environment...")
#   register( project_name, registry_name)
#
#   println("  removing package from registry environment ...")
#   Pkg.rm( project_name )

registry_environment = "/home/takbal/.julia/environments/local-packages"

def_project_location = "/home/takbal/takbal/projects/workspace_box"

compiled_txt = joinpath(def_project_location, "templates", "julia_compiled.txt")

# the name of the registry to use. We also determine the local registry checkout location from this
registry_name = "takbal"

# remote git server name or IP
remote_git_server = "10.10.10.3"

################### static params end

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

"""returns if the current directory's git repo is clean"""
function is_repo_clean()
    output = strip(read(`git status --porcelain`, String))
    return length(output) == 0
end

"""generates changelog with auto-changelog, and removes [AUTO] entries"""
function generate_changelog()
    # --ignore-commit-pattern ignores the entire release string
    run(`auto-changelog --commit-limit false -o CHANGELOG.md.orig`)
    run(pipeline(`sed '/^- \[AUTO\]/d'`, stdin="CHANGELOG.md.orig", stdout="CHANGELOG.md"))
    run(`rm CHANGELOG.md.orig`)
    run(`git add CHANGELOG.md`)
end

function generate_new_version(inc_ver_type::AbstractString,
        project_name::AbstractString, project_dir::AbstractString)

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

    # a bit stupid to check in the changelog post-release, but auto-changelog
    # needs the new release tag first to generate an entry for it

    println("tagging release in git ...")
    run(`git tag -a $new_version -m "RELEASE $new_version"`)

    println("creating changelog ...")
    generate_changelog()

    println("temporarily removing packages needed only for development ...")
    packages_to_readd = []
    for dp in development_packages
        # special case for Jtb itself: we need JuliaInterpreter as a dependency
        if dp == "JuliaInterpreter" && project_name == "Jtb"
            continue
        end
        if dp in keys(Pkg.project().dependencies)
            println("  removing $dp ...")
            Pkg.rm(dp)
            push!(packages_to_readd, dp)
        end
    end

    println("committing post-release changes ...")
    run(`git commit -a -m "[AUTO] post-release $new_version"`)

    println("pushing ...")
    run(`git push`)

    println("registering new version ...")
    with_working_directory(registry_environment) do
        run(`julia --project=$registry_environment register_package.jl $project_dir $project_name $registry_name`)
    end

    println("adding back removed development packages ...")
    for dp in packages_to_readd
        Pkg.add(dp)
    end

    println("pushing registry to remote server ...")
    with_working_directory( normpath(ENV["HOME"], ".julia", "registries", registry_name) ) do
        run(`git push`)
    end

end

function change_projectfile_version(path::AbstractString, v::VersionNumber)
    projectfile = Pkg.TOML.parsefile(path)
    projectfile["version"] = string(v)
    open(path, "w") do io
        Pkg.TOML.print(io, projectfile)
    end
end

function generate_image(project_dir::AbstractString)

    # this determines which packages to put into the image - not the same as using.txt
    to_sysimage = [ pkg.name for (key,pkg) in Pkg.dependencies() if pkg.is_direct_dep &&
                    !(pkg.name in noimage_packages) && !pkg.is_tracking_path ]

    using_fname = joinpath( project_dir, "using.txt" )

    if !isfile(using_fname)
        create_using_file(project_dir)
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
                println(io, "$(image_commands[p])")
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

function add_dev_packages()

    println("adding development packages ...")
    for dp in auto_packages
        Pkg.add(dp)
    end

end

function create_shared_env()

    print("new environment name: ")
    env_name = strip(readline())

    Pkg.activate(env_name, shared=true)

    if !isempty(Pkg.dependencies())
        println("package is not empty, not adding autodeps (use 'mkj addev')")
        exit()
    end

    project_dir = dirname(Pkg.project().path)
    add_dev_packages()

end

function create_new_project()

    print("new project (package) name: ")
    project_name = strip(readline())
    @assert !isempty(project_name) "you must supply a project name"

    print("parent directory of the project [$def_project_location]: ")
    project_location = strip(readline())
    if isempty(project_location)
        project_location = def_project_location
    end

    project_location = joinpath(project_location, project_name)
    @assert !ispath(project_location) "project already exists"

    println("generating template ...")
    Pkg.generate(project_location)

    template_location = normpath(project_location, "..", "templates", "julia")
    if isdir(template_location)
        println("copying additional template files ...")
        run(`rsync -a $template_location/ $project_location`)
        run(`ln -s $(compiled_txt) $(project_location)/compiled.txt`)
    end

    # set the new project's initial version to 0.0.0 rather than to the default 0.1.0
    change_projectfile_version(joinpath(project_location, "Project.toml"), v"0.0.0")

    Pkg.activate(project_location)
    add_dev_packages()

    println("creating git repository ...")
    with_working_directory(project_location) do
        run(`git init`)
        run(`git add .`)
        run(`git commit -m "[AUTO] initial check-in"`)

        remote_added = false

        print("add a local remote at $remote_git_server? [Y/n] ")
        if strip(readline()) != "n"
            run(`ssh git@$remote_git_server "new $project_name.git ; exit"`)
            run(`git remote add origin git@$remote_git_server:$project_name.git`)
            run(`git remote set-url --add --push origin git@$remote_git_server:$project_name.git`)
            remote_added = true
        end

        print("add a public remote at GitHub (gh and jq must work)? [y/N] ")
        if strip(readline()) == "y"
            print("enter your username: ")
            username = strip(readline())
            run(`gh auth login`)
            username = run(`gh api user | jq -r '.login'`)
            run(`gh repo create $project_name --public`)
            username = readchomp(pipeline(`gh api user`, `jq -r '.login'`))
            run(`git remote set-url --add --push origin https://github.com/$username/$project_name.git`)
            remote_added = true
        end

        if remote_added
            run(`git push --set-upstream origin master`)
        end

    end

end

function create_using_file(project_dir::AbstractString)

    println( "generating default using.txt with packages:")

    to_using = [ pkg.name for (key,pkg) in Pkg.dependencies() if pkg.is_direct_dep &&
                !(pkg.name in nousing_packages) && !pkg.is_tracking_path ]
    # put tracked packages last (these will not get compiled into the image)
    append!(to_using, [ pkg.name for (key,pkg) in Pkg.dependencies() if pkg.is_direct_dep &&
                !(pkg.name in nousing_packages) && pkg.is_tracking_path ])

    project_name = Pkg.project().name
    if !isnothing(project_name)
        push!(to_using, project_name)
    end

    open(joinpath( project_dir, "using.txt" ), "w") do io
        for p in to_using
            println(io, p)
            println( "  " * p)
        end
    end

    println( "overwriting compiled.txt with default")

    run(`ln -s -f $(compiled_txt) $(project_dir)/compiled.txt`)

end

function create_compiled()
    @eval open(compiled_txt, "w") do file
        visit(Base) do item
            if isa(item, Module)
                println(file, item)
            end
            return true
        end
    end
end

function generate_app(pdir, filter_stdlibs)
    create_app(pdir, joinpath(pdir, "app"); force=true, filter_stdlibs)
    for f in readdir( joinpath(pdir, "app", "lib"); join = true)
        if isfile(f)
            run(`strip $f`)
        end
    end
    for f in readdir( joinpath(pdir, "app", "lib", "julia"); join = true)
        if isfile(f)
            run(`strip $f`)
        end
    end
end

#################### script starts here

if length(ARGS) == 0 || !(ARGS[1] in ["new", "build", "major", "minor", "patch", "changelog",
                 "image", "addev", "env", "using", "compiled", "app"])

    println("Unknown task specified.")
    println()
    println(docstring)
    exit()

end

if ARGS[1] == "new"
    create_new_project()
elseif ARGS[1] == "env"
    create_shared_env()
elseif ARGS[1] == "compiled"
    create_compiled()
else

    with_working_directory(project_dir) do

        # this will keep PackageCompiler available from 'mk'
        Pkg.activate(project_dir)

        if ARGS[1] == "image"
            generate_image(project_dir)
        elseif ARGS[1] == "addev"
            add_dev_packages()
        elseif ARGS[1] == "using"
            create_using_file(project_dir)
        else
            # you must be in a project environment for the following to work

            @assert Pkg.project().ispackage "you are not in a package environment"

            if ARGS[1] == "build"
                Pkg.build(verbose = true)
            elseif ARGS[1] in ["major", "minor", "patch" ]
                generate_new_version(ARGS[1], project_name, project_dir)
            elseif ARGS[1] == "changelog"
                generate_changelog()
            elseif ARGS[1] == "app"
                generate_app(project_dir, length(ARGS) > 1 && ARGS[2] == "fltstd")
            else
                error("you should not get here")
            end

        end

    end

end
