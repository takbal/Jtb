"""
    anyslice(p, A::AbstractArray, dim)

Returns a BitVector storing the output of any(p, slice[:]) for each slice in dim, keeping
the selected dim. This is in contrast to any() that collapses the selected dim(s) to 1.
"""
anyslice(p, A::AbstractArray; dim) = BitArray( any(p, x) for x in eachslice(A; dims=dim) )

"""
    allslice(p, A::AbstractArray, dim)

Returns a BitVector storing the output of all(p, slice[:]) for each slice in dim, keeping
the selected dim. This is in contrast to all() that collapses the selected dim(s) to 1.
"""
allslice(p, A::AbstractArray; dim) = BitArray( all(p, x) for x in eachslice(A; dims=dim) )

"""
    propfill!(p, A::AbstractArray; dim, backwards::Bool=false, defvalue=NaN)

Fill by propagation along 'dim' all entries in A where predicate p returns true.
If backwards is true, operate from the end of the array.
Until p turns to false at least once, 'defvalue' is applied.

Example
--------

propfill!( isnan, [ NaN NaN ; 1 2 ; NaN NaN ; 3 4 ]; dim=1 )

4×2 Array{Float64,2}:
 NaN    NaN
   1.0    2.0
   1.0    2.0
   3.0    4.0

"""
function propfill!(p, A::AbstractArray; dim=1, backwards::Bool=false, defvalue=NaN)

    # we cannot use eachslice() due to backwards

    range = backwards ? reverse(axes(A,dim)) : axes(A,dim)

    if length(range) > 0

        if ndims(A) > 1

            buffer = copy(selectdim(A, dim, range[1]))
            buffer[p.(buffer)] .= defvalue

            for i in range
                v = selectdim(A, dim, i)
                locs = p.(v)
                nolocs = (!).(locs)
                buffer[nolocs] = v[nolocs]
                v[locs] = buffer[locs]
            end

        else

            # selectdim returns some crazy 0-dim value for 1-dim arrays

            buffer = p( getindex(A, range[1]) ) ? defvalue : getindex(A, range[1])

            for i in range
                if p(A[i])
                    A[i] = buffer
                else
                    buffer = A[i]
                end
            end

        end

    end

    return A
end
