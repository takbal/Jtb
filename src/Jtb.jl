module Jtb

include("array.jl")
export allslice, anyslice, propfill!

include("karray.jl")
export convert_eltype, extdim, unwrap, sync, sync_to, alldimsbut, convert_kc
export KeyedVector, KeyedMatrix, Keyed3D

include("logging.jl")
export add_file_logger, withtrace, BetterFileLogger

include("math.jl")
export nancumsum, nancumsum!, ismissingornan, ismissingornanorzero, nanfunc, nanmean, nanstd,
       nanvar, nanminimum, nanmaximum, nanmin, nanmax, nancumprod, nancumprod!, nansum, nanprod,
       cumsum_ignorenans, cumsum_ignorenans!, cumprod_ignorenans, cumprod_ignorenans!, map_lastn,
       groupfunc

include("datetime.jl")
export get_interval_indices

include("process.jl")
export is_pid_alive

include("plots.jl")
export imagesc, unfocus, add_keypress_handler, maximize, trace_fractile, trace_density

include("text.jl")
export boldify, italicify, printjson

include("julia.jl")
export typeinfo, compilemode, meth

include("stats.jl")
export fractiles

end # module
