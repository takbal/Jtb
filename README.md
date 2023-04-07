A collection of tools.

# INSTALL

The 'mkj' tool is a command line utility to help with creating new projects, images, releases, and more.

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

1. Copy the 'Jtb/template' folder to the location at templates/julia/ above, and edit it there to your liking.

2. To run the default image creation for the JLD2 package, also copy Jtb/julia_image_data to
   templates/julia_image_data/, as above.

3. For automatically using packages and enhance debugging speed, copy or merge 'Jtb/src/startup.jl' with yours.

# HOW TO SET UP A LOCAL REGISTRY

'mkj' allows adding local registries next to GitHub public and GitLab.

Read https://www.vogella.com/tutorials/GitHosting/article.html on how to create a local git user.

Add git-shell-commands, chsh git-shell. ssh -l git@localhost should work.

Login and add

```
new julia-registry.git
```

Then from a julia client, do

```
using LocalRegistry # add if missing, you can remove later
create_registry("{registry_name}", "git@{server}:julia-registry.git", description="private registry")
```

where {registry_name} is a name for the registry, and {server} is the IP. 'localhost' may work.

Then 

```
cd ~/.julia/registries/{registry_name}
g push --set-upstream origin master
```

From here "registry up" from pkg> should work for the private registry.
