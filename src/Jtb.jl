module Jtb

include("array.jl")
export allslice, anyslice, propfill!

include("karray.jl")
export convert_eltype, extdim, unwrap, sync, sync_to, alldimsbut, convert_kc
export transform_keys, replace_keys, shift_keys
export KeyedVector, KeyedMatrix, Keyed3D

include("logging.jl")
export add_file_logger, withtrace, BetterFileLogger

include("math.jl")
export nancumsum, nancumsum!, ismissingornan, ismissingornanorzero, nanfunc, nanmean, nanstd,
       nanvar, nanminimum, nanmaximum, nanmin, nanmax, nancumprod, nancumprod!, nansum, nanprod,
       cumsum_ignorenans, cumsum_ignorenans!, cumprod_ignorenans, cumprod_ignorenans!, map_lastn,
       groupfunc, fit_symmetric_parabola, equal_partition

export AdaptiveFractiles, observe!

include("datetime.jl")
export get_interval_indices, shortstring

include("process.jl")
export is_pid_alive

include("plots.jl")
export imagesc, unfocus, add_keypress_handler, maximize,
       trace_fractile, trace_density, closeall, disp,
       reset_color_idx, get_color, next_color_idx

include("text.jl")
export boldify, italicify, printjson

include("julia.jl")
export typeinfo, compilemode, meth, get_field_sizes

include("stats.jl")
export fractiles

include("files.jl")
export getdir

include("parexec.jl")
export parexec


using Pkg

function install_mkj(; force=false)

    my_location = dirname(realpath(@__FILE__))
    template_location = joinpath(my_location, "..", "template")
    image_data_location = joinpath(my_location, "..", "image_data")

    Pkg.activate("mkj", shared=true, io=devnull)

    mkj_dir = dirname(Pkg.project().path)
    target_template_location = joinpath(mkj_dir, "template")
    target_image_data_location = joinpath(mkj_dir, "image_data")

    # initial setup of the required libraries
    
    deps = [ x.second.name for x in Pkg.dependencies() if x.second.is_direct_dep ]
    
    if !("MethodAnalysis" in deps)
        Pkg.add("MethodAnalysis")
    end
    if !("PackageCompiler" in deps)
        Pkg.add("PackageCompiler")
    end
    if !("SymbolServer" in deps)
        Pkg.add("SymbolServer")
    end

    # do first what is surely ours
    cp(joinpath(my_location, "mkj.jl"), joinpath(mkj_dir, "mkj.jl"), force = true)
    cp(joinpath(my_location, "startup.jl"), joinpath(mkj_dir, "startup.jl"), force = true)
    cp(joinpath(my_location, "ju.sh"), joinpath(mkj_dir, "ju.sh"), force = true)

    if !isdir(target_image_data_location)
        run(`cp -a -f $image_data_location $mkj_dir`)
    elseif force
        println()
        println("overwriting existing image data")
        rm(target_image_data_location, recursive=true)
        run(`cp -a -f $image_data_location $mkj_dir`)
    else
        println()
        println("!!! skipped overwriting existing image_data")
    end

    if !isdir(target_template_location)
        run(`cp -a -f $template_location $mkj_dir`)
        println()
        println("copying template to \$HOME/.julia/environments/mkj/template, modify it to your liking")
    elseif force
        println()
        println("overwrting existing template to \$HOME/.julia/environments/mkj/template, modify it to your liking")
        rm(target_template_location, recursive=true)
        run(`cp -a -f $template_location $mkj_dir`)
    else
        println()
        println("!!! skipped overwriting existing template")
    end

    startup_dir = joinpath(ENV["HOME"], ".julia", "config")
    startup_file = joinpath(startup_dir, "startup.jl")
    if isfile(startup_file)
        println()
        println("!!! skipped overwriting existing startup.jl")
        println("if it is not yet done, add the following line to it:")
        println()
        println("   include( joinpath(ENV[\"HOME\"], \".julia\", \"environments\", \"mkj\", \"startup.jl\") )")
    else
        mkpath(startup_dir)
        open(startup_file, "w") do file
            print(file,
                """
                include( joinpath(ENV[\"HOME\"], \".julia\", \"environments\", \"mkj\", \"startup.jl\") )
                """             
            )
        end
    end

    println()
    println("if it is not yet done, add the following to your .bashrc / .zshrc:")
    println()
    println("   WORKSPACES=(workspace_dir1 workspace_dir2 ...) ")
    println("   source \$HOME/.julia/environments/mkj/ju.sh")
    println()
    println("in \$WORKSPACES, list all directories where you are placing projects. The default is the first one.")

end

end # module
