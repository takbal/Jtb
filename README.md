A collection of useful functions.

# installing `mkj`

The `mkj` tool is a stand-alone command line utility to help with creating new projects, images, releases, and more.

It installs its stuff in a private environment below `$HOME/.julia/environments/mkj`.

1. You will need the following executables to be present on your system:

- `julia` and `git` (of course)
- `auto-changelog` Python package (`pip install auto-changelog`)
- `glab` if you want to automatically create GitLab repos for new projects (https://gitlab.com/gitlab-org/cli/-/releases)
- `gh` and `jq` if you want to automatically create github repos for new projects (https://cli.github.com/, `sudo apt-get install jq`)
- `ssh` if you need a local git package server (see below how to set up one)

2. Temporarily install `Jtb`, then run `Jtb.install_mkj()`. Assuming `Jtb` is already registered:

```
$ julia
julia> using Pkg
julia> Pkg.activate(;tmp=true)
julia> Pkg.add("Jtb")
julia> using Jtb
julia> Jtb.install_mkj()
julia> exit()
```

3. For automatically using packages and enhance debugging speed, you will need to extend
your $HOME/.julia/config/startup.jl with the following:

```
include( joinpath(ENV["HOME"], ".julia", "environments", "mkj", "startup.jl" ) )
```

Upon installation, a startup file with this content is created automatically if it does not exists.

4. You will need to extend your .bashrc or .zshrc (the latter works with completion support) with the following:

```
WORKSPACES=(workspace_dir1 workspace_dir2 ...)
source $HOME/.julia/environments/mkj/ju.sh
```

Here specify the list of directories like $HOME/workspace where Julia projects will be located. `mkj new` will suggest the first of these to place a new project at.

With this addition, sysimages will get automatically used. You can also launch Julia in an env of any project found $WORKSPACES locations by issuing:

```
$ ju ProjectName [parameters]
```

In zsh, the ProjectName can be expanded automatically by hitting tab. `ju` or `ju .` will start the environment found in the current directory, or the global one if none found.

5. Edit the new project template below `$HOME/.julia/environments/mkj/template` to your liking. The content of this directory is going to be copied into each new project. The `mkj.toml` template contains further detailed explanations about its parameters in its comments, that are going to be removed for instantiated projects.

# Local registries

`mkj` support local registries via the `LocalRegistry` package. You need to set `name = {registry_name}` in the [local_registry] section of `mkj.toml`. If populated, then the new version will be automatically registered at each release. Alternatively, you can force registration anytime at a specific registry with `mkj register {registry_name}`.

# How to set up a git server

`mkj` supports setting up remotes to a git server. (`LocalPackageServer` may be better, but this came first.) Think it like your private github or gitlab - if you use those, you probably do not need this. 

Read https://www.vogella.com/tutorials/GitHosting/article.html on how to create a local git user.

Add git-shell-commands, chsh git-shell. ssh -l git@localhost should work.

Login and add

```
new julia-registry.git
```

This creates the repo for the registry. Then from a julia client, add the registry as usual for `LocalRegistry`:

```
using LocalRegistry # you can remove later
create_registry("{registry_name}", "git@{host}:julia-registry.git"; description="my private github!")
```

where {registry_name} is the name for the new registry, and {host} is the IP/host. 'localhost' does work.

Then 

```
cd ~/.julia/registries/{registry_name}
g push --set-upstream origin master
```

From here "registry up" from pkg> should work for your private package server. If a new project is created and the [git_server]/host is populated in `mkj.toml`, then `mkj new` will automatically create a repo at, and add a remote to the git server.
