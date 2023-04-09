A collection of useful functions.

# mkj

The `mkj` tool is a command line utility to help with creating new projects, images, releases, and more.

It runs stand-alone, without installing the package itself anywhere.

It assumes the following directory layout for your projects:

```
workspace/             # name is not important (if different, update ju.sh)
    Jtb/               # repo of this project
    Project1/          # your projects come here
    Project2/
    ...
    templates/
        julia/              # template for new projects
        julia_image_data/   # (optional) additional data for image creation
```

# installing `mkj`

1. You will need the following executables to be present on your system:

- `julia` and `git` (of course)
- `auto-changelog` Python package (`pip install auto-changelog`)
- `glab` if you want to automatically create GitLab repos for new projects (https://gitlab.com/gitlab-org/cli/-/releases)
- `gh` and `jq` if you want to automatically create github repos for new projects (https://cli.github.com/, `sudo apt-get install jq`)
- `ssh` if you need a local registry (see below how to set up one)

2. Copy the `Jtb/template` folder to the location at `templates/julia/` above, and edit it there to your liking.

3. To run some of the default image creation helpers, also copy `Jtb/julia_image_data` to
   `templates/julia_image_data/` as shown above.

4. For automatically using packages and enhance debugging speed, copy or merge `Jtb/src/startup.jl` with yours at `~/.julia/config/startup.jl`.

5. add the contents of `ju.sh` to your .bashrc or .zshrc (the latter with completion support). Edit the functions
if your workspace directory is different.

6. create a link on your $PATH by `ln -s {Jtb_checkout_dir}/src/mkj.jl mkj`.

# Local registries

`mkj` support local registries via the `LocalRegistry` package. You need to set `use = true` and `name = {registry_name}` in `mkj.toml`.
Upon releases, the new version will be automatically registered. Alternatively, you can force registration at a specific registry
with `mkj register {registry_name}`.

# Local git servers

`mkj` also supports setting up remotes to a local git server at package creation. (`LocalPackageServer` may be better, but this came first.)

Think it like your private github or gitlab - if you use those, you probably do not need this. 

# Howto set up a local git server

Read https://www.vogella.com/tutorials/GitHosting/article.html on how to create a local git user.

Add git-shell-commands, chsh git-shell. ssh -l git@localhost should work.

Login and add

```
new julia-registry.git
```

This creates the repo for the registry. Then from a julia client, add the registry as usual for `LocalRegistry`

```
using LocalRegistry # add if missing, you can remove later
create_registry("{registry_name}", "git@{server}:julia-registry.git", description="my private github!")
```

where {registry_name} is the name for the new registry, and {server} is the IP. 'localhost' may work.

Then 

```
cd ~/.julia/registries/{registry_name}
g push --set-upstream origin master
```

From here "registry up" from pkg> should work for your private package server. If a new project is created and the
[local_registry] section is populated in `mkj.toml`, then `mkj new` will automatically create a repo at, 
and add a remote to the local git server.
