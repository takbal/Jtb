using CSV, AxisKeys, DataStructures, UniqueVectors, NamedDims

const KeyedVector = KeyedArray{Element,1,NamedDimsArray{Names,Element,1,Container},
                Tuple{UniqueVector{RowType}}} where
                    {Element, Container, Names, RowType}

const KeyedMatrix = KeyedArray{Element,2,NamedDimsArray{Names,Element,2,Container},
                Tuple{UniqueVector{RowType},UniqueVector{ColType}}} where
                     {Element, Container, Names, RowType, ColType}

const Keyed3D = KeyedArray{Element,3,NamedDimsArray{Names,Element,3,Container},
                Tuple{UniqueVector{XType},UniqueVector{YType},UniqueVector{ZType}}} where
                     {Element, Container, Names, XType, YType, ZType}

"""
    KeyedArray(path::String; type, keys, dimnames, kwargs...)::KeyedArray

create KeyedArray from a file source.

Common keywords:

    keyword     default             description
    -------------------------------------------
    type        Array{Any,2}        the type of the underlying array that is going to be
                                    created. Must accept (undef,rows,cols) argumented constructor.
    dimnames    nothing             list of string to specify dimension names. Can be nothing
                                    in each dimension, or nothing to use defaults.
    keys        nothing             list of arrays, specifying keys in each dimension. To use
                                    defaults, can be nothing, or nothing per dim.

Further behaviour depends on the extension found.

.csv, .tsv, .txt:
-----------------
- Additional keywords are passed to the CSV.File function (e.g. header=..., dateformat=...).
- Output array is always 2-dimensional.
- Default dimnames are [ "rows", "columns" ].
- Default column keys are what CSV.File provides.
- An empty file throws an error.

Filetype specific keywords:

    keyword     default         description
    ---------------------------------------
    keycols      nothing         the column indices to use values from as row keys. If nothing,
                                 use default AxisKeys numbering. Otherwise, specify an array
                                 of column indices. If multiple columns defined, try to join
                                 them as a string.
"""
function AxisKeys.KeyedArray(path::AbstractString; type::DataType=Array{Any,2},
            dimnames=nothing, keys=nothing, keycols=nothing, kwargs...)::KeyedArray

    extension = splitext(path)[2]

    # CSV
    if extension in [".csv", ".txt", ".tsv"]

        data = CSV.File(path; kwargs...)
        numrows = length(data)
        @assert numrows > 0 "file contains no data"

        cks = [ String(ck) for ck in propertynames(data) ]

        # defaults

        if isnothing(dimnames)
            dimnames = ["rows", "columns"]
        else
            @assert length(dimnames) == 2
        end

        if isnothing(keys)
            keys = Any[ nothing, nothing ]
        else
            @assert length(keys) == 2
        end

        if !isnothing(keycols)
            for k in keycols
                actkeys = getproperty(data, Symbol(cks[k]) )
                if k == 1
                    keys[1] = actkeys
                else
                    keys[1] = string.(keys[1]) .* "," .* string.(actkeys)
                end
            end
            deleteat!(cks, keycols)
        end

        if isnothing(keys[2])
            keys[2] = cks
        end

        res = wrapdims( type(undef, numrows, length(cks)); Symbol(dimnames[1]) => keys[1],
                        Symbol(dimnames[2]) => keys[2] )

        for (i, row) in enumerate(data)
            actcol = 1
            for (j, d) in enumerate(row)
                if !isnothing(keycols) && j in keycols
                    continue
                end
                res[i,actcol] = d
                actcol += 1
            end
        end
        return res
    else
        error("unknown file type")
    end
end

"""
    karray_to_dict(K::KeyedArray)::Dict

Convert the 1-dimensional KeyedArray to a Dict.
"""
function Base.convert(::Type{T}, K::KeyedArray)::T where T <: AbstractDict
    @assert ndims(K) == 1
    return T( axiskeys(K)[1][i] => k for (i,k) in enumerate(K) )
end

"""
    AxisKeys.KeyedArray(D::AbstractDict, dimname::AbstractString="keys")::KeyedArray

Convert the dict to a 1-dimensional KeyedArray.
"""
function AxisKeys.KeyedArray(D::AbstractDict, dimname::AbstractString="keys")::KeyedArray
    return wrapdims(collect(values(D)); Symbol(dimname) => collect(keys(D)) )
end

"""
    convert_eltype(eltype::Type, K::KeyedArray; kwargs...)::KeyedArray

Convert the wrapped container to element type T. Extra arguments are passed to similar().
"""
function convert_eltype(eltype::Type, K::KeyedArray; kwargs...)::KeyedArray
    out = similar(K, eltype; kwargs...)
    out .= K
end

"""
    extdim(K::KeyedArray, dimname, label)::KeyedArray

Extend the passed KeyedArray with an extra dimension. Must supply a dimension name and a label
array for the existing data in the new dimension, like Kext = extdim(K, :foo, ["bar"]).
Returns the extended KeyedArray.

For the reverse operation, use dropdims(K, dims=:dimname).
"""
function extdim(K::KeyedArray, dimname::Symbol, label)::KeyedArray
    arraykeys = OrderedDict{Any,Any}( dimnames(K)[i] => axiskeys(K)[i] for i in 1:ndims(K))
    arraykeys[dimname] = label
    wrapdims( reshape( parent(parent(K)), (size(K)..., 1) ); arraykeys... )
end

"""
    unwrap(K::KeyedArray)

Abbreviation to get the the underlying array
"""
unwrap(K::KeyedArray) = parent(parent(K))

"""
    function sync_to(dims2keys::AbstractDict, K1, K2, ...; fillval=NaN)

Sync KeyedArrays simultaneously to the specified dimension => keys mapping. Returns the tuple
of the modified KeyedArrays.

Dimensions do not need to be in the same order, or to be present in all of the arrays, but old
keys and new keys must be comparable with the == operator for the same dimension.

Keys can be unsorted, but at randomly ordered keys, the remapping may take N^2
time. If the keys are (or close to being) sorted, the remapping is efficient, but a key in
the target that does not occur in the source runs at worst-case time (as we have to check all keys
that it is indeed missing). For large arrays, it is strongly recommended to sort the arrays
in the sync dimension beforehand, in order to use a more efficient algorithm.

If keys are not unique, multiple same-keyed values may get copied in the original order until
the same non-unique keys are present in the target keys. This works properly
only if there are no out-of-order keys between the non-unique ones; otherwise, it may happen
that the same non-unique keyed entry is copied multiple times for each non-unique target key.
In general, use sortkeys() before applying this function if you have non-unique keys.

Parameters:

    dims2keys     : a dimension::Symbol => key dict storing target keys
    K1, K2, ...   : KeyedArrays to sync (can be single)
    fillval       : use this value to fill newly added entries if necessary

Returns:
    transformed K1, K2, ... KeyedArrays

Example:

    K = sync_to(Dict(:x => ["foo","bar"]), K, fillval = 0)

    # K's :x dimension will have "foo" and "bar" keys. If it had values at them,
    # they are preserved, others are set to 0.
"""
function sync_to(dims2keys::AbstractDict, args...; fillval=NaN)

    out = KeyedArray[]

    for (i, K) in enumerate(args)

        # determine output array size

        newkeys = OrderedDict{Symbol,Any}()

        mod_found = false

        for d in dimnames(K)
            if d in keys(dims2keys)
                newkeys[d] = dims2keys[d]
                mod_found = true
            else
                newkeys[d] = axiskeys(K,d)
            end
        end

        if !mod_found
            @error "no sync dimension was found for argument #$i: $K"
        end

        # create the transformed array
        # try to keep the original eltype / container

        K_trans_unwrapped = similar( unwrap(K), [length(k) for (d,k) in newkeys]... )
        fill!(K_trans_unwrapped, convert(eltype(K), fillval) )

        getindices = []
        setindices = []

        for d in dimnames(K)

            if d in keys(dims2keys)

                # determine axiskeys(K,d) -> newkeys[d] mapping

                fromkeys = axiskeys(K,d)
                tokeys = newkeys[d]

                from_order = Int64[]
                to_order = Int64[]
                # these will never hold more than this amount
                sizehint!(from_order, length(tokeys))
                sizehint!(to_order, length(tokeys))

                fromidx_start = 1

                sorted = issorted(fromkeys) && issorted(tokeys)

                for (toidx, k) in enumerate(tokeys)

                    if !sorted

                        # if we cannot assume that keys in either are unique or sorted, the
                        # worst case is N^2 when keys are in random order in both. But we
                        # can start the search so that if keys are - or close to - being
                        # sorted the algo becomes efficient. This is sadly still N lookup
                        # to determine if the target key is not present in the source.

                        found = true
                        numkeys = length(fromkeys)
                        # search from previous:end
                        fromidx = _findmore(k, fromkeys, fromidx_start, numkeys)
                        if fromidx > numkeys
                            # not found; search from 1:previous-1
                            fromidx = _findmore(k, fromkeys, 1, fromidx_start-1)
                            if fromidx == fromidx_start
                                found = false
                            end
                        end
                        if found
                            fromidx_start = fromidx == length(fromkeys) ? 1 : fromidx + 1
                            push!(from_order, fromidx)
                            push!(to_order, toidx)
                        end

                    else # keys are sorted, we can determine missing keys by a single lookahead
                         @inbounds for fromidx = fromidx_start:length(fromkeys)
                             if k == fromkeys[fromidx]
                                # set next search startpoint
                                fromidx_start = fromidx + 1
                                push!(from_order, fromidx)
                                push!(to_order, toidx)
                                break
                            elseif k < fromkeys[fromidx]
                                fromidx_start = fromidx
                                break
                            end
                        end

                    end

                end # loop in target keys

                push!(getindices, from_order)
                push!(setindices, to_order)
            else
                push!(getindices, Colon())
                push!(setindices, Colon())
            end

        end

        setindex!(K_trans_unwrapped, view(unwrap(K), getindices...), setindices...)

        K_trans = wrapdims(K_trans_unwrapped; newkeys...)

        push!(out, K_trans)

    end

    if length(out) == 1
        return out[1]
    else
        return Tuple(out)
    end

end

"""
    sync(K1, K2...; type=:inner, dims::Union{AbstractArray{Symbol,1},Nothing}=nothing, fillval=NaN)

Sync KeyedArrays to each other in the specified dimensions. Returns the tuple of the modified KeyedArrays.

Dimensions do not need to be in the same order, or to be present in all of the arrays, but key types
must match if the dimension matches.

Outgoing keys are going to be sorted. If keys were not unique, only one of them is going to be
preserved (due to union() and intersect() is dropping multiple copies).

The function tries to preserve the key store type of the first input.

Calls sync_to() internally, see some tips there.

Parameters:

    K1, K2, ... : KeyedArrays to sync (must be more than one)
    type        : if :inner, target intersect of keys, if :outer, take union
    dims        : the dimension(s) to do the syncing in. If nothing, sync all dimensions.
    fillval     : use this value to fill newly added entries if necessary.

Examples:

    K1, K2 = sync(K1, K2)

    # sync all dimensions to the set of common keys (intersect).

    K1, K2 = sync(K1, K2, type=:outer)

    # sync all dimensions to the union of keys. New values are going to be set to NaN.

    K1, K2 = sync(K1, K2, dims=:x)

    # sync the :x dimension to the set of common keys. K1 and K2 must have :x with
    # the same key type, but it can be at a different index.
"""
function sync(args...; type=:inner,
            dims::Union{Symbol,Tuple,AbstractArray{Symbol,1},Nothing}=nothing,
            fillval=NaN)

    @assert length(args) > 1 "you need to specify more then one KeyedArrays"

    # determine target keys in each dimension

    if isnothing(dims)
        # add all dims
        dims = union( [dimnames(x) for x in args]... )
    end

    d2k = Dict{Symbol,Any}()

    if typeof(dims) == Symbol
        dims = (dims,)
    end

    for d in dims
        origkeys = [ axiskeys(x, d) for x in args if d in dimnames(x) ]
        # try to preserve key store type of the first input
        keystoretype = typeof(origkeys[1])
        if type === :inner
            d2k[d] = keystoretype(sort(intersect(origkeys...)))
        elseif type === :outer
            d2k[d] = keystoretype(sort(union(origkeys...)))
        else
            @error "unknown sync type: $type"
        end
    end

    sync_to(d2k, args...; fillval)

end

function _findmore(item, collection, startidx::Int64, endidx::Int64)::Int64
    actidx::Int64 = startidx
    @inbounds while actidx <= endidx && collection[actidx] != item
        actidx += 1
    end
    return actidx
end

"""
    convert_kc(K::KeyedArray, container_type::Type=UniqueVector)::KeyedArray

Returns a modified KeyedArray where key containers are replaced by the specified type.
Using a type like UniqueVector can improve lookup speed of indexing.
"""
convert_kc(K::KeyedArray, container_type::Type=UniqueVector)::KeyedArray =
    KeyedArray( NamedDimsArray( unwrap(K), dimnames(K)), tuple( [ container_type(x) for x in axiskeys(K) ]...) )

"""
    alldimsbut(K::KeyedArray, querydim)

Return index of all dimensions except the specified one (which can be a Symbol).
"""
alldimsbut(K::KeyedArray, querydim) = setdiff( 1:ndims(K), dim(parent(K), querydim) )

### generic AbstractArray helpers
#################################

"""
    anyslice(p, A::AbstractArray, dim)

Returns a BitVector storing the output of any(p, slice[:]) for each slice in dim.
"""
anyslice(p, A::AbstractArray, dim) = BitArray( any(p, x) for x in eachslice(A; dims=dim) )

"""
    allslice(p, A::AbstractArray, dim)

Returns a BitVector storing the output of all(p, slice[:]) for each slice in dim.
"""
allslice(p, A::AbstractArray, dim) = BitArray( all(p, x) for x in eachslice(A; dims=dim) )
