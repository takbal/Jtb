using InteractiveUtils, JuliaInterpreter

"""
    my_show_method(io::IO, m::Method)

stolen and changed from methodshow.jl to have the file printed when it is part of stdlib
"""
function my_show_method(io::IO, m::Method)
    tv, decls, file, line = Base.arg_decl_parts(m)
    sig = Base.unwrap_unionall(m.sig)
    if sig === Tuple
        # Builtin
        print(io, m.name, "(...) in ", m.module)
        return
    end
    print(io, decls[1][2], "(")
    join(
        io,
        String[isempty(d[2]) ? d[1] : string(d[1], "::", d[2]) for d in decls[2:end]],
        ", ",
        ", ",
    )
    kwargs = Base.kwarg_decl(m)
    if !isempty(kwargs)
        print(io, "; ")
        join(io, map(Base.sym_to_string, kwargs), ", ", ", ")
    end
    print(io, ")")
    Base.show_method_params(io, tv)
    print(io, " in ", m.module)
    if line > 0
        file, line = Base.updated_methodloc(m)
        # this is the only change in this function:
        # print(io, " at ", file, ":", line) replaced by:
        fname = normpath(Base.find_source_file(file));
        if isnothing(fname)
            print(io, " at ", file, ":", line);
        else
            print(io, " at ", normpath(Base.find_source_file(file)), ":", line)
        end
    end
end


"""
    my_show_method_table(io::IO, ms::Base.MethodList, max::Int=-1, header::Bool=true)

stolen and changed from methodshow.jl to have the file printed when it is part of stdlib
"""
function my_show_method_table(io::IO, ms::Base.MethodList, max::Int=-1, header::Bool=true)
    mt = ms.mt
    name = mt.name
    hasname = isdefined(mt.module, name) &&
              typeof(getfield(mt.module, name)) <: Function
    if header
        Base.show_method_list_header(io, ms, str -> "\""*str*"\"")
    end
    n = rest = 0
    local last

    last_shown_line_infos = get(io, :last_shown_line_infos, nothing)
    last_shown_line_infos === nothing || empty!(last_shown_line_infos)

    for meth in ms
        if max==-1 || n<max
            n += 1
            println(io)
            print(io, "[$n] ")
            # this is the only change in this function:
            # show(io, meth)
            my_show_method(io, meth)
            file, line = Base.updated_methodloc(meth)
            if last_shown_line_infos !== nothing
                push!(last_shown_line_infos, (string(file), line))
            end
        else
            rest += 1
            last = meth
        end
    end
    if rest > 0
        println(io)
        if rest == 1
            show(io, last)
        else
            print(io, "... $rest methods not shown")
            if hasname
                print(io, " (use methods($name) to see them all)")
            end
        end
    end
end



"""
    typeinfo(x, st::Bool=false)

prints supertypes, subtypes and methodswith for the type, or the type of the object.
Passes the st parameter to methodswith (if true, show methods for supertypes).
"""
function typeinfo(x, st::Bool=false)

    if !isa(x, Type)
        x = typeof(x)
    end

    println("       type: ", string(x))

    println()

    println("   isabstract: ", isabstracttype(x))
    println("   isconcrete: ", isconcretetype(x))
    println("     isstruct: ", isstructtype(x))
    println("    ismutable: ", ismutabletype(x))
    println("  issingleton: ", Base.issingletontype(x))
    println("       isbits: ", isbitstype(x))

    println()

    println(" supertypes: ", supertypes(x))
    println("   subtypes: ", subtypes(x))

    println("\nconstructors:\n")

    meth(x)

    println("\n\nmethodswith:\n")
    ms = methodswith(x; supertypes=st)
    for m in ms
        my_show_method(stdout, m)
        println()
    end

end

"""
    compilemode(x...)

add modules, all methods of a function, or methods to JuliaInterpreter's compiled lists.
"""
function compilemode(x...)

    for i in x
        if isa(i, Module)
            push!(JuliaInterpreter.compiled_modules, i)
        elseif isa(i, Function)
            m = collect(methods(i))
            union!(JuliaInterpreter.compiled_methods, m)
        elseif isa(i, Method)
            union!(JuliaInterpreter.compiled_methods, i)
        end
    end

end

"""
    meth(x)

alternative to methods(x) that always show the file location
"""
meth(x) = my_show_method_table(stdout, methods(x))


"""
    get_field_sizes(x)

recursively print field sizes in kbytes of struct types
"""
function get_field_sizes(v; tabsize = 0)

    if isstructtype(typeof(v))
        fns = fieldnames(typeof(v))
        for x in fns
            actv = getfield(v, x)
            println(repeat(" ", tabsize) * "$(string(x)) : $(Base.summarysize(actv)/1e3)k")
            if isstructtype(typeof(actv))
                get_field_sizes(actv; tabsize = tabsize + 4)
            end
        end
    else
        println("variable is not a struct type")
    end

end


"""
    gc_if(;takenGB::Float64 = Inf, freeGB::Float64 = 0.)

Trigger garbage collection if total memory taken is higher than 'takenGB', or 
free memory is less than 'freeGB' in megabytes.

Manual GC triggers seems essential in multi-threaded code, as julia seems to
be clueless when to do it.
"""
function gc_if(takenGB::Float64 = Inf, freeGB::Float64 = 0.)
    if Sys.maxrss() / 2^30 > takenGB || Sys.free_memory() / 2^30 < freeGB
        GC.gc()
    end
end
