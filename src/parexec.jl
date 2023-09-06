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
"""
function parexec(f; sweeps...)

    all_tuples = vec(collect(Iterators.product(values(sweeps)...)))
    all_params = [ Dict(zip(keys(sweeps), t)) for t in all_tuples ]

    println("number of parameter combinations: $(length(all_params))")

    Threads.@threads for p in all_params
        f(; p...)
    end
    
end
