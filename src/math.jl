using Statistics

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
