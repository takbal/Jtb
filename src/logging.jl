using Logging, LoggingExtras, Dates

"""
    add_file_logger(filename::String, append::Bool=false)

add a timestamped file logger to the global logger if is a ConsoleLogger, and return the combined logger

you can use it like global_logger( add_file_logger(filename) )
"""
function add_file_logger(filename::String, append::Bool=false)

    if global_logger() isa ConsoleLogger

        timestamp_logger(logger) = TransformerLogger(logger) do log
            merge(log, (; message = "[$(Dates.format(now(), "yyyy-mm-dd HH:MM:SS"))] $(log.message)"))
        end

        return TeeLogger( global_logger(), timestamp_logger( FileLogger(filename; append) ) )

    else
        return global_logger()
    end

end
