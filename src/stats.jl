"""
    indices, lbounds, ubounds = function fractiles(X, numbins::Int=10;
                                ignore::Union{Nothing,Function,AbstractArray}=ismissingornan)

Fractile calculation for X by splitting the range of X into N (approximately) equally
sized bins.

Inputs:

    X: data

    numbins:
required to be smaller than the number of valid entries

    ignore:
either nothing, or a function that returns true for x ϵ X if that must be ignored, or an array sized
X that is true for values that must be ignored.

Returns:

    indices:
a 'numbins' length vector, storing vectors of indices into X for each bin.

    lbounds, ubounds:
'numbins' sized arrays storing the lower and the upper bound of each fractile.

A value x in X gets bin index 'i' if lbounds[i] <= x <= ubounds[i]. The first bin's lower
bound is the minimal value in X, and the last bin's upper value is the maximal value in X.

THe function uses sortperm(), therefore if not ignored, NaN and missing values get to the end.
"""
function fractiles(X, numbins::Int=10; ignore::Union{Nothing,Function,AbstractArray}=ismissingornan)

    keeploc = nothing

    if !isnothing(ignore)
        if typeof(ignore) <: Function
            keeploc = (!).(ignore).(X)
        else
            keeploc = .!ignore
        end
    end

    if !isnothing(keeploc)
        num_keeps = count(keeploc)
    else
        num_keeps = length(X)
    end

    @assert num_keeps >= numbins "not enough data to split into $numbins fractiles"

    fractile_size = num_keeps / numbins

    sortorder = sortperm( view(X, Colon()) )
    if !isnothing(keeploc)
        keeploc = keeploc[sortorder]
    end

    # split it into equal bins

    indices = Vector{Int64}[]
    for b in 1:numbins
        v = Vector{Int64}()
        sizehint!(v, Int64(ceil(fractile_size)))
        push!(indices,v)
    end

    lower_bounds = Vector{eltype(X)}()
    upper_bounds = deepcopy(lower_bounds)
    sizehint!(lower_bounds, numbins)
    sizehint!(upper_bounds, numbins)

    act_bin = 1
    act_count = 1
    newbin = true
    for (idx,val) in enumerate(sortorder)
        if isnothing(keeploc) || keeploc[idx]
            if newbin
                push!(lower_bounds, X[val])
                newbin = false
            end
            push!(indices[act_bin], val)
            act_count += 1
            if act_count > round(act_bin * fractile_size)
                push!(upper_bounds, X[val])
                act_bin += 1
                newbin = true
            end
        end
    end

    return indices, lower_bounds, upper_bounds

end
