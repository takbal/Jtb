module Jtb

include("array.jl")
export allslice, anyslice, propfill!

include("karray.jl")
export convert_eltype, extdim, unwrap, sync, sync_to, alldimsbut, convert_kc
export KeyedVector, KeyedMatrix, Keyed3D

include("logging.jl")
export add_file_logger, withtrace, BetterFileLogger

include("math.jl")
export nancumsum, nancumsum!, ismissingornan, nanfunc, nanmean, nanstd, nanvar, nanminimum,
       nanmaximum, nanmin, nanmax, nancumprod, nancumprod!, cumsum_ignorenans, cumsum_ignorenans!,
       cumprod_ignorenans, cumprod_ignorenans!, map_lastn

include("datetime.jl")
export get_interval_indices

include("process.jl")
export is_pid_alive

include("plots.jl")
export imagesc, unfocus, add_keypress_handler, maximize

include("text.jl")
export boldify, italicify

include("julia.jl")
export typeinfo, compilemode, meth

end # module
