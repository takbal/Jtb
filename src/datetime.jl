using Dates

"""
    start, finish = get_interval_indices(data::Array{T}, Period::DataType) where T <: TimeType

Returns two arrays storing the first and last indices in data for each interval defined by changing Periods.
Data must be sorted.

"""
function get_interval_indices(data::Array{T}, Period::DataType) where T <: TimeType

    @assert issorted(data) "data is not sorted"

    last_day_indices = findall( abs.(diff(Period.(data))) .> Period(0) )
    first_day_indices = [ 1 ; deepcopy(last_day_indices) .+ 1 ]
    push!(last_day_indices, length(data))
    
    return first_day_indices, last_day_indices
end