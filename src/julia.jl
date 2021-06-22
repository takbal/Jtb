using InteractiveUtils, JuliaInterpreter

"""
    my_show_method(io::IO, m::Method)

stolen and changed from methodshow.jl to have the file printed when it is part of stdlib
"""
function my_show_method(io::IO, m::Method)
    tv, decls, file, line = Base.arg_decl_parts(m)
    sig = Base.unwrap_unionall(m.sig)
    ft0 = sig.parameters[1]
    ft = Base.unwrap_unionall(ft0)
    d1 = decls[1]
    if sig === Tuple
        # Builtin
        print(io, m.name, "(...) in ", m.module)
        return
    end
    if ft <: Function && isa(ft, DataType) &&
            isdefined(ft.name.module, ft.name.mt.name) &&
                # TODO: more accurate test? (tn.name === "#" name)
            ft0 === typeof(getfield(ft.name.module, ft.name.mt.name))
        print(io, ft.name.mt.name)
    elseif isa(ft, DataType) && ft.name === Type.body.name
        f = ft.parameters[1]
        if isa(f, DataType) && isempty(f.parameters)
            print(io, f)
        else
            print(io, "(", d1[1], "::", d1[2], ")")
        end
    else
        print(io, "(", d1[1], "::", d1[2], ")")
    end
    print(io, "(")
    join(io, String[isempty(d[2]) ? d[1] : d[1]*"::"*d[2] for d in decls[2:end]],
                 ", ", ", ")
    kwargs = Base.kwarg_decl(m)
    if !isempty(kwargs)
        print(io, "; ")
        join(io, kwargs, ", ", ", ")
    end
    print(io, ")")
    Base.show_method_params(io, tv)
    print(io, " in ", m.module)
    if line > 0
        file, line = Base.updated_methodloc(m)
        # this is the only change in this function:
        print(io, " at ", normpath(Base.find_source_file(file)), ":", line)
    end
end

"""
    my_show_method(io::IO, m::Method)

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

    resize!(Base.LAST_SHOWN_LINE_INFOS, 0)
    for meth in ms
        if max==-1 || n<max
            n += 1
            println(io)
            print(io, "[$n] ")
            # this is the only change in this function:
            my_show_method(io, meth)
            file, line = Base.updated_methodloc(meth)
            push!(Base.LAST_SHOWN_LINE_INFOS, (string(file), line))
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
