#!/bin/bash
#=
exec julia --project=@. --color=yes --startup-file=no "${BASH_SOURCE[0]}" "$@" =#

docstring = """
tool to perform usual tasks on a Julia project

    Usage: mk TASK

Where task is one of:

    new           : create a new project (guided: enter package name and location)
    build         : run the build script (deps/build.jl)
    major         : generate a major release
    minor         : generate a minor release
    patch         : generate a patch release
    changelog     : auto-generate changelog (also called if a release is made)

    Generating a release will first check if repo is clean, and the tests run without failure.
    Then it is going to create the changelog, and checks it in.
"""

using Pkg

################### static params start

# these are the packages that will got temporarily removed before making a release, so they are not going to be a dependency
development_packages = ["Revise", "Atom", "Juno", "StaticLint", "PkgAuthentication"]

# automatically added packages for a new project
auto_packages = ["Revise", "Atom", "Juno"]

# this is a Julia environment where the registry is going to added from. It must have LocalRegistry added as a dependency and
# register_package.jl in its root with the content:
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

# the name of the registry to use. We also determine the local registry checkout location from this
registry_name = "takbal"

# remote git server name or IP
remote_git_server = "10.10.10.3"

################### static params end

"""temporarily switch to this dir; works with the do keyword"""
function with_working_directory(f::Function, path::AbstractString)
    prev_wd = pwd()
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

function generate_new_version(inc_ver_type::AbstractString, project_name::AbstractString, project_dir::AbstractString)

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
    with_working_directory( normalpath(ENV["HOME"], ".julia", "registries", registry_name) ) do
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

#################### script starts here

# first determine path to the canonical project location

myname = PROGRAM_FILE
if islink(PROGRAM_FILE)
    myname = readlink(PROGRAM_FILE)
end
my_home_dir = dirname(myname)

def_project_location = normpath(my_home_dir, "..", "..")

if !(ARGS[1] in ["new", "build", "major", "minor", "patch", "changelog"])
    println("Unknown task specified.")
    println()
    println(docstring)
    exit()
end

if ARGS[1] == "new"

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
    end

    println("creating remote ...")
    run(`ssh git@$remote_git_server "new $project_name.git ; exit"`)

    # set the new project's initial version to 0.0.0 rather than to the default 0.1.0
    change_projectfile_version(joinpath(project_location, "Project.toml"), v"0.0.0")

    println("adding auto packages ...")
    Pkg.activate(project_location)
    for dp in auto_packages
        Pkg.add(dp)
    end

    println("adding git repository ...")
    with_working_directory(project_location) do
        run(`git init`)
        run(`git add .`)
        run(`git commit -m "[AUTO] initial check-in"`)
        run(`git remote add origin git@$remote_git_server:$project_name.git`)
        run(`git push --set-upstream origin master`)
    end

else
    # try to find out the current environment. We do not let continue if we are in a default environment

    @assert Pkg.project().ispackage "you are not in a package environment"

    project_dir = dirname(Pkg.project().path)
    project_name = Pkg.project().name

    with_working_directory(project_dir) do

        if ARGS[1] == "build"
            Pkg.build(verbose = true)
        elseif ARGS[1] in ["major", "minor", "patch" ]
            generate_new_version(ARGS[1], project_name, project_dir)
        elseif ARGS[1] == "changelog"
            generate_changelog()
        else
            error("unknown task")
        end

    end

end
