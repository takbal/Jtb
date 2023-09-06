"""
    parexec(f; sweeps...)

Parallel execute f() with all variations of parameters.

All parameters passed must be vectors.

Example:

    parexec(f; param1=[1,2,3], param2=["a",b"])

will threaded execute the following:

    f(param1=1, param2="a")
    f(param1=2, param2="a")
    f(param1=3, param2="a")
    f(param1=1, param2="b")
    f(param1=2, param2="b")
    f(param1=3, param2="b")

Outputs:

A tuple of the return values of the functions in a vector, and the keyword parameters generated.
"""
function parexec(f; sweeps...)

    all_tuples = vec(collect(Iterators.product(values(sweeps)...)))
    all_params = [ Dict(zip(keys(sweeps), t)) for t in all_tuples ]

    println("number of parameter combinations: $(length(all_params))")

    outputs = Vector{Any}(undef, length(all_params))

    Threads.@threads for idx in axes(all_params,1)
        outputs[idx] = f(; all_params[idx]...)
    end
    
    return outputs, all_params

end
