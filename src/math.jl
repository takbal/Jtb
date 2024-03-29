using Statistics, DataStructures

"""
    nancumsum(A; kwargs...)

Similar to cumsum but zeroes out NaNs in A before.
"""
function nancumsum(A; kwargs...)
    tmp = deepcopy(A)
    tmp[ broadcast(isnan, tmp) ] .= 0
    out = similar(tmp)
    cumsum!(out, tmp; kwargs...)
end

"""
    nancumsum!(B, A; kwargs...)

Similar to cumsum! but zeroes out NaNs in A before.
Warning: changes A as well.
"""
function nancumsum!(B, A; kwargs...)
    A[ broadcast(isnan, A) ] .= 0
    cumsum!(B, A; kwargs...)
end

"""
    cumsum_ignorenans(A; kwargs...)

Similar to cumsum but ignores NaNs in A.
"""
function cumsum_ignorenans(A; kwargs...)
    tmp = deepcopy(A)
    nans = broadcast(isnan, tmp)
    tmp[nans] .= 0
    out = similar(tmp)
    cumsum!(out, tmp; kwargs...)
    out[nans] .= NaN
    return out
end

"""
    cumsum_ignorenans!(B, A; kwargs...)

Similar to cumsum! but ignores NaNs in A.
Warning: changes A as well.
"""
function cumsum_ignorenans!(B, A; kwargs...)
    nans = broadcast(isnan, A)
    A[nans] .= 0
    cumsum!(B, A; kwargs...)
    B[nans] .= NaN
    return B
end

"""
    nancumprod(A; kwargs...)

Similar to cumprod but changes NaNs to 1 in A before.
"""
function nancumprod(A; kwargs...)
    tmp = deepcopy(A)
    tmp[ broadcast(isnan, tmp) ] .= 1
    out = similar(tmp)
    cumprod!(out, tmp; kwargs...)
end

"""
    nancumprod!(B, A; kwargs...)

Similar to cumprod! but changes NaNs to 1 in A before.
Warning: changes A as well.
"""
function nancumprod!(B, A; kwargs...)
    A[ broadcast(isnan, A) ] .= 1
    cumprod!(B, A; kwargs...)
end

"""
    cumprod_ignorenans(A; kwargs...)

Similar to cumprod but ignores NaNs in A.
"""
function cumprod_ignorenans(A; kwargs...)
    tmp = deepcopy(A)
    nans = broadcast(isnan, tmp)
    tmp[nans] .= 1
    out = similar(tmp)
    cumprod!(out, tmp; kwargs...)
    out[nans] .= NaN
    return out
end

"""
    cumprod_ignorenans!(B, A; kwargs...)

Similar to cumprod! but ignores NaNs in A.
Warning: changes A as well.
"""
function cumprod_ignorenans!(B, A; kwargs...)
    nans = broadcast(isnan, A)
    A[nans] .= 1
    cumprod!(B, A; kwargs...)
    B[nans] .= NaN
    return B
end

"""
    ismissingornan(x)

returns if x is missing or x is nan
"""
ismissingornan(x) = ismissing(x) || isnan(x)

"""
    ismissingornanorzero(x)

returns if x is missing or x is nan or x is zero
"""
ismissingornanorzero(x) = ismissing(x) || isnan(x) || iszero(x)

"""
    nanfunc(f::Function, A::AbstractArray; dims=:)

apply f to A, ignoring NaNs. Works with mean, var and others.

Specializations: [`nanmean`](@ref), [`nanstd`](@ref), [`nanvar`](@ref), [`nanminimum`](@ref), [`nanmaximum`](@ref), [`nansum`](@ref), [`nanprod`](@ref)
"""
nanfunc(f::Function, A::AbstractArray; dims=:) = _nanfunc(f, A, dims)
function _nanfunc(f::Function, A::AbstractArray, ::Colon)
    tmp = filter(!isnan, A)
    # needed for minimum / maximum
    if isempty(tmp)
        return convert(eltype(A), NaN)
    else
        return f(tmp)
    end
end
_nanfunc(f::Function, A::AbstractArray, dims) = mapslices(a->_nanfunc(f,a,:), A; dims)

@doc (@doc nanfunc)
nansum(A::AbstractArray; kwargs...) = nanfunc(sum, A; kwargs...)
@doc (@doc nanfunc)
nanprod(A::AbstractArray; kwargs...) = nanfunc(prod, A; kwargs...)
@doc (@doc nanfunc)
nanmean(A::AbstractArray; kwargs...) = nanfunc(mean, A; kwargs...)
@doc (@doc nanfunc)
nanstd(A::AbstractArray; kwargs...) = nanfunc(std, A; kwargs...)
@doc (@doc nanfunc)
nanvar(A::AbstractArray; kwargs...) = nanfunc(var, A; kwargs...)
@doc (@doc nanfunc)
nanminimum(A::AbstractArray; kwargs...) = nanfunc(minimum, A; kwargs...)
@doc (@doc nanfunc)
nanmaximum(A::AbstractArray; kwargs...) = nanfunc(maximum, A; kwargs...)

"""
    nanmax(x,y)

returns max(x,y), but ignores NaNs unless both x and y are NaN.
"""
nanmax(x,y) = isnan(x) ? y : ( isnan(y) ? x : max(x,y) )

"""
    nanmin(x,y)

returns min(x,y), but ignores NaNs unless both x and y are NaN.
"""
nanmin(x,y) = isnan(x) ? y : ( isnan(y) ? x : min(x,y) )

"""
    map_lastn(f, v::AbstractVector, N::Int; default=NaN, out_eltype=eltype(v))

For all index i in v, apply f to the vector formed from the previous N not-nan and
non-missing value of v up to index i-1, and store the result at index i. If there
are no N values yet collected, use the default value. If the last N values accessible
did not change, then recycle the previous value. The output vector has
the same size as v. You can control the default value and the type of the
output vector elements.
"""
function map_lastn(f, v::AbstractVector, N::Int; default=NaN, out_eltype=eltype(v))

    out = similar(v, out_eltype)

    # a slightly lower allocation, same speed
    # dqueue = Deque{eltype(v)}()
    dqueue = Vector{eltype(v)}()

    filled = false
    changed = true

    for (i,x) in enumerate(v)
        if !filled
            filled = length(dqueue) == N
        end
        if filled
            if changed
                out[i] = f(dqueue)
            else
                out[i] = out[i-1]
            end
        else
            out[i] = default
        end
        if !ismissing(x) && !isnan(x)
            if filled
                popfirst!(dqueue)
            end
            push!(dqueue, x)
            changed = true
        else
            changed = false
        end
    end

    return out
end

"""
    groupfunc(f, X, groups::AbstractVector[])

apply f to groups in X defined by index lists, then concatenate results.

Input:

- `f`: the function to apply to indexed subsets of X

- `X`: data

- `groups`: collection of vectors of indices, each defining a group

Outputs a length(groups) sized vector.
"""
function groupfunc(f, X, groups::AbstractVector)

    out = Vector(undef, length(groups))

    for (idx,g) in enumerate(groups)
        out[idx] = f(X[g])
    end

    return out

end

"""
    fit_symmetric_parabola(X::AbstractArray, Y::AbstractArray)

OLS fit to a set of (x_i, y_i) points of a parabolic curve constrained to y = y0 + αx^2.
Returns the y0 and α parameters.
"""
function fit_symmetric_parabola(X::AbstractArray, Y::AbstractArray)

    @assert length(X) == length(Y) "mismatch in X and Y size"
    @assert length(X) > 1 "need at least two points"

    A = sum(X .^ 2)
    B = sum(Y)
    C = sum(X .^ 4)
    D = sum(Y .* (X .^ 2))
    N = length(X)
    det = N*C - A^2

    @assert det != 0 "undefined solution"

    y0 = (C*B - A*D) / det
    alpha = (N*D - A*B) / det

    return y0, alpha

end

"""
    equal_partition(n::Int64, parts::Int64)

Splits `n` into `parts` number of pieces that are as close to equally sized as possible.
Returns `n` parts if `n` < `parts`.
"""
function equal_partition(n::Int64, parts::Int64)
    if n < parts
        return [ x:x for x in 1:n ]
    end
    starts = push!(Int64.(round.(1:n/parts:n)), n+1)
    return [ starts[i]:starts[i+1]-1 for i in 1:length(starts)-1 ]
end

"""
    equal_partition(V::AbstractVector, parts::Int64)

Splits `V` into `parts` number of disjunct views that are as close to equally sized as possible.
Returns `n` parts if `n` < `parts`.
    """
function equal_partition(V::AbstractVector, parts::Int64)
    ranges = equal_partition(length(V), parts)
    return [ view(V,range) for range in ranges ]
end


mutable struct AdaptiveFractiles
    # center of each fractile
    centers::Vector{Float64}
    # how much to move towards the middle value on each update
    decay_rate::Float64
    # how much to move the matching centroid
    update_rate::Float64
end


"""
    AdaptiveFractiles(;
        num_bins::Int64,
        decay_rate::Float64,
        update_rate::Float64,
        initial_range_center::Float64 = 0.,
        initial_range::Float64 = 2.)

Create an AdaptiveFractiles struct, that maintains a crude and fast on-line estimation
of fractile bins of the univariate data observed so far.

Inputs:

    num_bins:
The number of fractiles to estimate

    decay_rate:
The rate to move the centers towards the middle of center span on each update. Should 
be smaller than update_rate.

    update_rate:
The rate to move the center towards the observation on each update. Should be larger
than update_rate.

    initial_range_center:
The mean of the initial range.

    initial_range:
The width of the initial range.
"""
function AdaptiveFractiles(;
    num_bins::Int64,
    decay_rate::Float64,
    update_rate::Float64,
    initial_range_center::Float64 = 0.,
    initial_range::Float64 = 2.)

    initial_centers = initial_range .* ( 0:(num_bins-1) ) ./ (num_bins-1)
    initial_centers = initial_centers .- nanmean(initial_centers)
    initial_centers = initial_centers .+ initial_range_center

    return AdaptiveFractiles(initial_centers, decay_rate, update_rate)

end


"""
    observe!(af::AdaptiveFractiles, obs::Float64)

Update AdaptiveFractiles with an observation.
Returns the bin the observation was classified into.
"""
function observe!(af::AdaptiveFractiles, obs::Float64)

    # shrink centers towards middle
    middle = (af.centers[end] + af.centers[1]) / 2
    for i in axes(af.centers,1)
        af.centers[i] *= 1-af.decay_rate
        af.centers[i] += af.decay_rate * middle
    end

    # determine closest center
    closest = argmin(abs.(af.centers .- obs))

    # update closest center
    af.centers[closest] *= 1-af.update_rate
    af.centers[closest] += af.update_rate * obs

    return closest

end
