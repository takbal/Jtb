#!/bin/bash
#=
exec julia --project=/home/takbal/.julia/environments/compress --sysimage /home/takbal/.julia/environments/compress/JuliaSysimage.so --color=yes --startup-file=no "${BASH_SOURCE[0]}" "$@"
=#
# exec julia --project=/home/takbal/.julia/environments/compress_dev --sysimage /home/takbal/.julia/environments/compress_dev/JuliaSysimage.so --color=yes --startup-file=no "${BASH_SOURCE[0]}" "$@"


using JLD2, AxisKeys, BenchmarkTools, FileIO, ArgParse, Pkg, JLD

docstring = """
tool to change compression / format of JLD / JLD2 files containing KeyedArrays
"""

function parse_commandline()
    s = ArgParseSettings(description=docstring)

    @add_arg_table! s begin
        "-t","--comptype"
            help = "one of 'bzip2', 'zlib', 'blosc', 'lz4' or 'none'"
            arg_type = String
            required = true
        "file"
            help = "the .jld/.jld2 file to read"
            required = true
        "target"
            help = "the .jld/.jld2 file to write"
            required = true
    end

    return parse_args(s)
end

###############
# hack BloscCompressor and BloscDecompressor into its namespace
# this could be removed if https://github.com/JuliaIO/Blosc.jl/issues/79 is done

newjld2 = false

if basename(dirname(Pkg.project().path)) == "compress_dev"

    newjld2 = true

    using Blosc, CodecBzip2, CodecZlib, CodecLz4

    Blosc.eval(:(struct BloscCompressor end))
    Blosc.eval(:(struct BloscDecompressor end))
    import Blosc: BloscCompressor, BloscDecompressor
    import JLD2: TranscodingStreams

    TranscodingStreams.transcode(::BloscCompressor, buf) = Blosc.compress(buf)
    TranscodingStreams.initialize(::BloscCompressor) = nothing
    TranscodingStreams.finalize(::BloscCompressor) = nothing

    TranscodingStreams.transcode(::BloscDecompressor, buf) = Blosc.decompress(UInt8, buf)
    TranscodingStreams.initialize(::BloscDecompressor) = nothing
    TranscodingStreams.finalize(::BloscDecompressor) = nothing

    compressors = Dict{String,Any}(
        "bzip2" => CodecBzip2.Bzip2Compressor(),
        "zlib"  => CodecZlib.ZlibCompressor(),
        "blosc" => Blosc.BloscCompressor(),
        "lz4"   => CodecLz4.LZ4FrameCompressor(),
        "none"  => false
        )

end

###############

args = parse_commandline()

if ispath(args["target"])
    @error "target exists"
    exit()
end

if !ispath(args["file"])
    @error "file does not exists"
    exit()
end

if !(splitext(args["file"])[2] in [".jld", ".jld2"])
    @error "unknown file extension"
    exit()
end

input = load(args["file"])

if splitext(args["target"])[2] == ".jld2"

    if newjld2

        JLD2.jldopen(args["target"], "w", compress=compressors[args["comptype"]]) do file
            for (key, val) in input
                JLD2.write(file, key, val)
            end
        end

    else

        if args["comptype"] == "zlib"
            c = true
        elseif args["comptype"] == "none"
            c = false
        else
            @error "cannot use other than 'zlib' codec with JLD2 old version"
        end

        JLD2.jldopen(args["target"], "w", compress=c) do file
            for (key, val) in input
                JLD2.write(file, key, val)
            end
        end

    end

elseif splitext(args["target"])[2] == ".jld"

    if args["comptype"] == "blosc"
        c = true
    elseif args["comptype"] == "none"
        c = false
    else
        @error "cannot use other than 'blosc' codec with JLD"
    end

    JLD.jldopen(args["target"], "w", compress=c) do file
        for (key, val) in input
            JLD.write(file, key, val)
        end
    end

else

    @error "unknown extension"
    exit()

end
