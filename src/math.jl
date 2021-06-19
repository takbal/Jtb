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
    nanfunc(f::Function, A::AbstractArray; dims=:)

apply f to A, ignoring NaNs. Works with mean, var and others.

Specializations: [`nanmean`](@ref), [`nanstd`](@ref), [`nanvar`](@ref), [`nanminimum`](@ref), [`nanmaximum`](@ref)
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
    map_lastn(f, v::AbstractVector, N::Int; default=NaN)

For all index i in v, apply f to the vector formed from the previous N not-nan and
non-missing value of v up to index i-1, and store the result at index i. If there
are no N values yet collected, use the default value. The resulting vector has
the same size as v.
"""
function map_lastn(f, v::AbstractVector, N::Int; default=NaN)

    out = similar(v)

    # a slightly lower allocation, same speed
    dqueue = Deque{eltype(v)}()
    # dqueue = fill(default, (0,))
    
    filled = false

    for (i,x) in enumerate(v)
        if !filled
            filled = length(dqueue) == N
        end
        if filled
            out[i] = f(dqueue)
        else
            out[i] = default
        end
        if !ismissing(x) && !isnan(x)
            if filled
                popfirst!(dqueue)
            end
            push!(dqueue, x)
        end
    end

    return out
end
