"""
    nancumsum(A; kwargs...)

Similar to cumsum but zeroes out NaNs in A before.
"""
function nancumsum(A::AbstractArray{T}; kwargs...) where T <: AbstractFloat
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
function nancumsum!(B, A::AbstractArray{T}; kwargs...) where {T <: AbstractFloat}
    A[ broadcast(isnan, A) ] .= 0
    cumsum!(B, A; kwargs...)
end
