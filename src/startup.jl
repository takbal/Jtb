# copy this file (or merge with existing) below ~/.julia/config/startup.jl for using / compiled in mkj.jl to work

atreplinit() do repl

    # hack to avoid running this twice if PlotlyJS is used
    if repl.options.tabwidth == 8
        repl.options.tabwidth = 7

        @eval using Pkg

        project_file = Base.active_project()
        project_dir = dirname(project_file)
        manifest_file = joinpath( project_dir, "Manifest.toml")

        # check if the sysimage loaded matches the current project file
        pf_mismatch = false
        if isfile(project_file * ".sysimage")
            img_pf = readlines( project_file * ".sysimage" )
            if isfile(project_file)
                orig_pf = readlines( project_file )
            else
                orig_pf == ""
            end
            if orig_pf != img_pf
                pf_mismatch = true
            end
        end

        mf_mismatch = false
        if isfile(manifest_file * ".sysimage")
            img_mf = readlines( manifest_file * ".sysimage" )
            if isfile(manifest_file)
                orig_mf = readlines( manifest_file )
            else
                orig_mf == ""
            end
            if orig_mf != img_mf
                mf_mismatch = true
            end
        end
        if pf_mismatch || mf_mismatch
            @warn "Project or manifest files changed, please re-generate image."
        end

        if isfile(joinpath(project_dir, "mkj.toml"))
            
            config = Pkg.TOML.parsefile(joinpath(project_dir, "mkj.toml"))

            if !isempty(config["using"]["packages"])
                print("using")
                for tmp in config["using"]["packages"]
                    print(" $(tmp),")
                    if tmp != "Revise" # we do that later
                        eval( Meta.parse( "using $(tmp)" ) )
                    end
                end
                println("\b ")
            end

            # set specified modules to compiled for faster debugging

            direct_deps = [ pkg.name for (_,pkg) in Pkg.dependencies() if pkg.is_direct_dep ]
            if "JuliaInterpreter" in direct_deps
                @eval using JuliaInterpreter
                for item in config["compiled"]["modules"]
                    push!(JuliaInterpreter.compiled_modules, Module(Symbol(item)))
                end
            end
        end

        # run Revise separately as last
        try
            @eval using Revise
        catch
        end
        # vscode's recommendation
        # @async try
        #     sleep(0.1)
        #     @eval using Revise
        #     @async Revise.wait_steal_repl_backend()
        # catch
        # end
    end
end
ENV["JULIA_EDITOR"] = "code"
