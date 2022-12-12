using Dates

"""
    start, finish = get_interval_indices(data::Array{T}, Period::DataType) where T <: TimeType

Returns two arrays storing the first and last indices in data for each interval defined by changing Periods.
Data must be sorted.

"""
function get_interval_indices(data::AbstractArray{<:TimeType}, Period::DataType)

    @assert issorted(data) "data is not sorted"

    last_day_indices = findall( abs.(Base.diff(Period.(data))) .> Period(0) )
    first_day_indices = [ 1 ; deepcopy(last_day_indices) .+ 1 ]
    push!(last_day_indices, length(data))

    return first_day_indices, last_day_indices
end

# allow conversion of Time to DateTime with a fake date, so plotting works with Time x labels
Base.convert(::Type{DateTime}, t::Time) = DateTime(0, 1, 1, Hour(t).value,
                                                    Minute(t).value, Second(t).value )

"""
    shortstring(cp::Dates.CompoundPeriod)

A shorter version to show a CompoundPeriod.
"""
function shortstring(cp::Dates.CompoundPeriod)
    s = ""
    for (idx,p) in enumerate(cp.periods)
        s *= string(Dates.value(p)) * lowercase(string(typeof(p))[1])
        if idx !=length(cp.periods)
            s *= ":"
        end
    end
    return s
end
