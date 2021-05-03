using InteractiveUtils, JuliaInterpreter

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

    println("methodswith:")
    display(methodswith(x; supertypes=st))

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
