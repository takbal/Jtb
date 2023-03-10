using CSV, AxisKeys, DataStructures, UniqueVectors, NamedDims, AcceleratedArrays

# these tools assume that KeyedArrays are created by NamedDimsArray as a parent

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
    Base.convert(K::KeyedArray)::Dict

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
    extdim(K::KeyedArray, dimname=:_, label=nothing; atdim=nothing)::KeyedArray

Extend the passed KeyedArray with an extra dimension. Must supply a dimension name and a label
array for the existing data in the new dimension, like Kext = extdim(K, :foo, ["bar"]).
Returns the extended KeyedArray.

You can supply an unkeyed dimension by specifying :_ as dimname and 'nothing' as keys (the default).

The extended dimension will be the last by default. Specify the 'atdim' keyword to tell the index
of the new dimension. Later dimensions are shifted in index by one.

For the reverse operation, use dropdims(K, dims=:dimname).
"""
function extdim(K::KeyedArray, dimname::Symbol=:_, label=nothing; atdim=nothing)::KeyedArray
    arraykeys = OrderedDict{Any,Any}( dimnames(K)[i] => axiskeys(K)[i] for i in 1:ndims(K))
    arraykeys[dimname] = label
    out = wrapdims( reshape( parent(parent(K)), (size(K)..., 1) ); arraykeys... )

    if !isnothing(atdim)
        out = permutedims(out, [collect(1:atdim-1) ; ndims(out) ; collect(atdim:ndims(out)-1)])
    end

    return out
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

If the keys are, or close to being sorted, the remapping takes only O(N) time. Keys can 
be randomly ordered, but in this case, the remapping may take O(N^2) time at worst. For large
arrays, it is recommended to sort the arrays in the sync dimension beforehand, in order
to use a more efficient algorithm.

If keys are not unique, multiple same-keyed values may get copied in the original order until
the same non-unique keys are present in the target keys. This works properly
only if there are no out-of-order keys between the non-unique ones; otherwise, it may happen
that the same non-unique keyed entry is copied multiple times for each non-unique target key.
In general, use sortkeys() before applying this function if you have non-unique keys.

# Parameters:

- `dims2keys`     : a dimension::Symbol => key dict storing target keys
- `K1`, `K2`, ...   : KeyedArrays to sync (can be single)
- `fillval`       : use this value to fill newly added entries if necessary. If set to
                    `nothing`, filling is skipped (this is useful if keys are not extended,
                    but can be dangerous otherwise).

# Returns:

transformed K1, K2, ... KeyedArrays as a tuple, or a single transformed KeyedArray

# Example:

    K = sync_to(Dict(:x => ["foo","bar"]), K, fillval = 0)

K's `:x` dimension will have "foo" and "bar" keys. If it had values at them,
they are preserved, others are set to 0.
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
        if !isnothing(fillval)
            fill!(K_trans_unwrapped, convert(eltype(K), fillval) )
        end

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
                        # worst case is O(N^2) when keys are in random order in both. But we
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
    sync_to(K::KeyedArray, K1, K2, ...; dims=nothing, fillval=NaN)

Sync KeyedArrays simultaneously to the keys of the specified KeyedArray for the specified
dimensions (`nothing` sync all). Returns the tuple of the modified KeyedArrays. Uses `sync_to` internally;
see that method for detailed usage.
"""
function sync_to(to_karray::KeyedArray, args...; fillval=NaN, dims::Union{Symbol,Tuple,AbstractVector{Symbol},Nothing}=nothing)
    if isnothing(dims)
        dims = dimnames(to_karray)
    end
    if typeof(dims) == Symbol
        dims = (dims,)
    end
    d2k = Dict{Symbol,Any}()        
    for d in dims
        d2k[d] = axiskeys(to_karray, d)
    end

    return sync_to(d2k, args...; fillval)
end

"""
    sync(K1, K2...; type=:inner, dims=nothing, fillval=NaN, keys_only::Bool=false)

Sync KeyedArrays to each other in the specified dimensions. Returns the tuple of the modified KeyedArrays.

Dimensions can be constrained to a subset in `dims` or use all available if `nothing` is specified. They do not need
to be in the same order, or to be present in all of the arrays, but key types must match if the
dimension matches.

Outgoing keys are going to be sorted. If keys were not unique, only one of them is going to be
preserved (due to union() and intersect() is dropping multiple copies).

The function tries to preserve the key store type of the first input.

Calls sync_to() internally, see some tips there.

# Parameters:

- K1, K2, ... : KeyedArrays to sync (must be more than one)
- type        : if :inner, target intersect of keys, if :outer, take union
- dims        : the dimension(s) to do the syncing in. If nothing, sync all dimensions.
- fillval     : use this value to fill newly added entries if necessary (ignored for :inner).
- keys_only   : if true, do not sync arrays, just return the unified key lists

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
            dims::Union{Symbol,Tuple,AbstractVector{Symbol},Nothing}=nothing,
            fillval=NaN, keys_only::Bool=false)

    @assert length(args) > 1 "you need to specify more then one KeyedArrays"

    # skip filling if keys are constrained
    if :type == :inner
        fillval = nothing
    end

    # determine target keys in each dimension

    if isnothing(dims)
        # add all dims
        dims = union( [dimnames(x) for x in args]... )
    end

    if typeof(dims) == Symbol
        dims = (dims,)
    end

    d2k = Dict{Symbol,Any}()

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

    if keys_only
        return d2k
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

Returns a modified KeyedArray where key containers are converted to the specified type.
Using a type like UniqueVector can improve lookup speed of indexing.

For AcceleratedArrays, specify the index type, like one of HashIndex,
UniqueHashIndex, SortIndex or UniqueSortIndex.
"""
function convert_kc(K::KeyedArray, container_type::Type=UniqueVector)::KeyedArray

    if container_type in [HashIndex, UniqueHashIndex, SortIndex, UniqueSortIndex]
        return KeyedArray( NamedDimsArray( unwrap(K), dimnames(K)), tuple( [ if isa(x, AcceleratedArray) x else accelerate(x, container_type) end for x in axiskeys(K) ]...) )
    else
        return KeyedArray( NamedDimsArray( unwrap(K), dimnames(K)), tuple( [ if isa(x, container_type) x else container_type(x) end for x in axiskeys(K) ]...) )
    end

end

"""
    alldimsbut(K::KeyedArray, querydim)

Return index of all dimensions except the specified one (which can be a Symbol).
"""
alldimsbut(K::KeyedArray, querydim) = setdiff( 1:ndims(K), dim(parent(K), querydim) )

"""
    diff(K::KeyedArray; dims, removefirst::Bool=true)

A diff() specialization that works for KeyedArrays and named dimensions.
if 'removefirst' is true, the first key is removed in the dimension, otherwise the last.
"""
function Base.diff(K::KeyedArray; dims, removefirst::Bool=true)

    range = removefirst ? (2:size(K, dims)) : (1:size(K,dims)-1)
    out = similar(selectdim(K, dims, range) )
    out[:] = Base.diff(unwrap(K); dims=NamedDims.dim(parent(K),dims))

    return out

end

"""
    transform_keys(f, K::KeyedArray; dim)

Returns a new KeyedArray with the same content but f applied to all keys in dim.
The call preserves the container type, but uses an intermediate Array.

# Examples

    transform_keys(d->d+Day(1), K; dim=:dates)

This adds a day to keys, so lags the data *backwards*. Note that this will add
previously non-existent keys if there are gaps in the dates.
"""
function transform_keys(f, K::KeyedArray; dim)
    old_keys = axiskeys(K, dim)
    container_type = typeof(old_keys)
    new_keys = container_type( [ f(x) for x in old_keys ] )
    return replace_keys(new_keys, K; dim)
end

"""
    replace_keys(keys, K::KeyedArray; dim)

Returns a new KeyedArray with the keys in dimension `dim` changed to `keys`.
"""
function replace_keys(keys::AbstractVector, K::KeyedArray; dim)

    newkeys = Base.setindex( axiskeys(K), keys, NamedDims.dim(K, dim) )

    return wrapdims( unwrap(K); OrderedDict(zip(dimnames(K), newkeys))...  )
    
end

"""
    shift_keys(amount::Int, K::KeyedArray; dim)

Returns a new KeyedArray with the keys in `dim` shifted backward of forward by `amount`.
The call preserves the container type, but may use an intermediate Array.
Data that has no key after the shift are dropped.

# Examples

    shift_keys(1, K; dim=:dates)

This moves all dates forward by 1, so lags the data *backwards*. The data for the last
date are dropped, and the first date is not available anymore.
"""
function shift_keys(amount::Int, K::KeyedArray; dim)

    oldk = axiskeys(K, dim)
    container_type = typeof(oldk)
    lower_bound = max(1,1+amount)
    upper_bound = min(length(oldk),length(oldk)+amount)
    newk = container_type( oldk[lower_bound:upper_bound] )

    newkeys = Base.setindex( axiskeys(K), newk, NamedDims.dim(K, dim) )

    olda = axes(K, dim)
    lower_bound = max(1,1-amount)
    upper_bound = min(length(oldk),length(oldk)-amount)
    newa = olda[lower_bound:upper_bound]

    newaxes = Base.setindex( axes(K), newa, NamedDims.dim(K, dim) )

    return wrapdims(unwrap(K)[newaxes...]; OrderedDict(zip(dimnames(K), newkeys))...)
end
