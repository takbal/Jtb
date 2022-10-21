# copy this file below ~/.julia/config/startup.jl for mk.jl to work

atreplinit() do repl
    @eval using Pkg
    # parse using.txt
    project_dir = dirname(Base.active_project())
    using_file = joinpath( project_dir, "using.txt")
    compiled_file = joinpath( project_dir, "compiled.txt")
    if isfile( using_file )
        # check if the sysimage loaded matches the current project file
        try
            manifest_file = joinpath( project_dir, "Manifest.toml")
            orig_mf = readlines( manifest_file )
            img_mf = readlines( manifest_file * ".sysimage" )
            project_file = Base.active_project()
            orig_pf = readlines( project_file )
            img_pf = readlines( project_file * ".sysimage" )
            if orig_mf != img_mf || orig_pf != img_pf
                @warn "Project files changed, please re-generate image."
            end
        catch
        end
        open( using_file, "r" ) do file
            print("using")
            for tmp in eachline(file)
                print(" $(tmp),")
                if tmp != "Revise" # we do that later
                    eval( Meta.parse( "using $(tmp)" ) )
                end
            end
            println("\b ")
        end
    end
    # set specified modules to compiled for faster debugging
    if isfile( compiled_file )
        try
            @eval using JuliaInterpreter
            open( compiled_file, "r" ) do file
                for item in eachline(file)
                    push!(JuliaInterpreter.compiled_modules, Module(Symbol(item)))
                end
            end
        catch
        end
    end
    # run Revise separately
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
ENV["JULIA_EDITOR"] = "code"