using CSV, AxisKeys

import AxisKeys

"""
    KeyedArray(path::String; type, keys, dimnames, kwargs...)

create KeyedArray from a file source.

Common keywords:

    keyword     default             description
    -------------------------------------------
    type        Array{Any,2}        the type of the underlying array that is going to be created. Must accept (undef,rows,cols) argumented constructor.
    dimnames    nothing             list of string to specify dimension names. Can be nothing in each dimension, or nothing to use defaults.
    keys        nothing             list of arrays, specifying keys in each dimension. To use defaults, can be nothing, or nothing per dim.

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
    keycol      nothing         the column index to use values from as row keys. If nothing, use default AxisKeys numbering.
"""
function AxisKeys.KeyedArray(path::AbstractString; type::DataType=Array{Any,2}, dimnames=nothing, keys=nothing, keycol=nothing, kwargs...)

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

        if !isnothing(keycol)
            keys[1] = getproperty(data, Symbol(cks[keycol]) )
            deleteat!(cks, keycol)
        end

        if isnothing(keys[2])
            keys[2] = cks
        end

        res = wrapdims( type(undef, numrows, length(cks)); Symbol(dimnames[1]) => keys[1], Symbol(dimnames[2]) => keys[2] )

        for (i, row) in enumerate(data)
            actcol = 1
            for (j, d) in enumerate(row)
                if j == keycol
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
function karray_to_dict(K::KeyedArray)::Dict
    @assert ndims(K) == 1
    return Dict( axiskeys(K)[1][i] => k for (i,k) in enumerate(K) )
end

"""
    dict_to_karray(D::AbstractDict, dimname::AbstractString="keys")::KeyedArray

Convert the dict to a 1-dimensional KeyedArray.
"""
function dict_to_karray(D::AbstractDict, dimname::AbstractString="keys")::KeyedArray
    return wrapdims(collect(values(D)); Symbol(dimname) => collect(keys(D)) )
end

"""
    convert_wrapped(K::KeyedArray, eltype; kwargs...)::KeyedArray

Convert the wrapped container to element type T. Extra arguments are passed to similar().
"""
function convert_wrapped(K::KeyedArray, eltype; kwargs...)::KeyedArray
    out = similar(K, eltype; kwargs...)
    out .= K
end
