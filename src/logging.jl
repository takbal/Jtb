using Logging, LoggingExtras, Dates

import Base.CoreLogging:
    AbstractLogger, SimpleLogger,
    handle_message, shouldlog, min_enabled_level, catch_exceptions

"""
    add_file_logger(filename::String, append::Bool=false)

add a timestamped file logger to the global logger if is a ConsoleLogger, and return the combined logger

you can use it like global_logger( add_file_logger(filename) )
"""
function add_file_logger(filename::String, append::Bool=false )

    if global_logger() isa ConsoleLogger
        mkpath(dirname(filename))
        return TeeLogger( global_logger(), BetterFileLogger(filename; append) )
    else
        return global_logger()
    end

end

"""
    withtrace(e, msg=nothing)

Generate a string that contains the stacktrace in a catch.
This works with file logging, unlike exception=(err,st).
Use it like:

...
catch err
    @error withtrace(err, "problem") or
    @warning withtrace(err, "problem")
end
"""
@inline function withtrace(e, msg=nothing)
    buffer = IOBuffer();
    if !isnothing(msg)
        println(buffer, msg)
    end
    println(buffer, e)
    st = stacktrace(catch_backtrace());
    for (idx, l) in enumerate(st)
        println(buffer, " [$idx] $l")
    end
    return(String(take!(buffer)))
end

"""
    BetterFileLogger(stream=stderr, min_level=Info)

A mix of LoggingExtras.FileLogger and Base.SimpleLogger that does not print
lines if module, filepath and line are all nothing.
"""
struct BetterFileLogger <: AbstractLogger
    stream::IO
    min_level::LogLevel
    source_level::LogLevel
    print_date::Bool
    always_flush::Bool
    message_limits::Dict{Any,Int}
end

function BetterFileLogger(path; append=false, kwargs...)
    stream = open(path, append ? "a" : "w")
    BetterFileLogger(stream, kwargs...)
end

function BetterFileLogger(stream::IOStream; always_flush=true, print_date=true,
        level=Base.CoreLogging.Info, source_level=Base.CoreLogging.Warn)
    BetterFileLogger(stream, level, source_level, print_date, always_flush, Dict{Any,Int}())
end

# shouldlog(logger::BetterFileLogger, level, _module, group, id)
shouldlog(logger::BetterFileLogger, ::Any, ::Any, ::Any, id) = get(logger.message_limits, id, 1) > 0

min_enabled_level(logger::BetterFileLogger) = logger.min_level

catch_exceptions(logger::BetterFileLogger) = false

function handle_message(logger::BetterFileLogger, level, message, _module, group, id,
                        filepath, line; maxlog=nothing, kwargs...)
    if maxlog !== nothing && maxlog isa Integer
        remaining = get!(logger.message_limits, id, maxlog)
        logger.message_limits[id] = remaining - 1
        remaining > 0 || return
    end
    buf = IOBuffer()
    iob = IOContext(buf, logger.stream)
    levelstr = level == Base.CoreLogging.Warn ? "Warning" : string(level)
    msglines = split(chomp(string(message)), '\n')
    for (key, val) in kwargs
        push!(msglines, "  " * string(key) * " = " * string(val))
    end
    if level >= logger.source_level
        push!(msglines, "@ " * string(something(_module, "nothing")) * " " *
            string(something(filepath, "nothing")) * ":" * string(something(line, "nothing")))
    end
    prefixstr = length(msglines) > 1 ? "┌ " : "  "
    if logger.print_date
        prefixstr *= "[$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))] "
    end
    println(iob, prefixstr, levelstr, ": ", msglines[1])
    for i in 2:length(msglines)-1
        println(iob, "│ ", msglines[i])
    end
    if length(msglines) > 1
        println(iob, "└ ", msglines[end])
    end
    write(logger.stream, take!(buf))
    logger.always_flush && flush(logger.stream)
    nothing
end
