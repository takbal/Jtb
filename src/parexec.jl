using JLD2, Logging, LoggingExtras, Dates, ProgressMeter

"""
    A type assumed to have parameters as properties.
    Typically, such types are created through @kwdef or @with_kw of Parameters.jl.
"""
abstract type AbstractParameters end

"""
    sweep_parameters(p::T; sweeps...)::Vector{T} where T <: AbstractParameters

Returns a vector of sweep parameter variations of p.

Sweeps in keywords passed must be vectors, and each keyword has to be a parameter in p. All possible
combinations of passed sweeps are going to be produced. The parameters not in the sweeps will remain
the same.

If no keyword arguments specified, the function simply places p in a vector.
"""
function sweep_parameters(p::T; sweeps...)::Vector{T} where T <: AbstractParameters

    if isnothing(sweeps)
        return [ p ]
    end

    fn = propertynames(p)

    @assert all([ k in fn for k in keys(sweeps) ]) "some sweep parameters are not properties of type $(T)"
    all_tuples = vec(collect(Iterators.product(values(sweeps)...)))
    all_params = [ Dict(zip(keys(sweeps), t)) for t in all_tuples ]

    outputs = [ deepcopy(p) for _ in axes(all_params,1) ]

    for i in axes(outputs, 1)
        for k in keys(all_params[i])
            setfield!(outputs[i], k, all_params[i][k])
        end
    end
    
    return outputs

end


"""
    status, outdirs = parexec(f::Function, params::AbstractVector{T};
                              force::Bool = false,
                              force_clean::Bool = false,
                              clear_logs::Bool = false,
                              progress_freq_sec::Float64 = 2,
                              print_log_of_failed_jobs::Bool = true) where T <: AbstractParameters

Parallel execution over multiple parameters.

The `f` function specified will be called as the following:
    
    f(p, outdir::String, progressrep::Function) where p <: AbstractParameters

Here the parameters are the following:

    `p`:
the parameter struct for this job (an element of the original 'params' array, see also `sweep_parameters()`)
    
    `outdir`:
a directory where output is expected to be saved. The directory name is created as follows: ENV["PAREXEC_DIR"] / name of f / hash of parameters

    'progressrep':
a function to report execution progress. It expects a Float between 0 and 1. Do not call it too frequently, as it (may) use files.

Expect the output directory to get populated by the following automatically:

    1. before start: a (paramtype).params file, storing an instance of the parameters passed in a human-readable text,

    2. during run: a log.txt file, where the output of @info, @warn, @error ... macros are redirected while executing f() (with timestamps).
       If an error was captured, the error and stacktrace is also dumped into this file,

    3. after ending the function: an out.jld2 file containing the returned variable from f(). If the job finished with an error, this file
       is not written. If `force` or `force_clean` is true, the existence of this file is checked to test if re-running is necessary,

    4. (optionally) it may contain a progress.txt with the value of the current progress.

If `out.jld2` is already present in the output directory, the job is not going to get executed.

Keyword arguments
------------------

    force:
Clear out.jld2 files for each job before running, forcing all parameterisations to re-execute.

    force_clean:
Clear files found in the target directories, apart from logfiles. Implies 'force'. Subdirectories are not touched.

    clear_logs:
Clear the logfiles for each job that is going to execute, otherwise append to the existing logfile.

    progress_freq_sec:
How often to show progress of tasks, in seconds. Set it to Inf to turn off progress reporting.

    print_log_of_failed_jobs:
if true, print the log of failed jobs after finish

Output
------
The function returns a 3-element tuple:
- a vector of returned values,
- list of directories for each parameter,
- the list of failed jobs.

During execution, progress bars are shown with the overall progress, plus the progress of selected, slowest
or failed jobs.

See also
--------
`sweep_parameters()` for one way of generating the range of input parameterisations.
"""
function parexec(f::Function, p::AbstractVector{T};
                 basedir::String = ENV["PAREXEC_DIR"],
                 force::Bool = false,
                 force_clean::Bool = false,
                 clear_logs::Bool = false,
                 progress_freq_sec::Float64 = 2,
                 print_log_of_failed_jobs::Bool = true) where T <: AbstractParameters

    output_dirs = [ joinpath(basedir, string(f), string(hash(x))) for x in p ]

    if force
        for d in output_dirs
            rm(joinpath(d, "out.jld2"); force = true)
        end
    end

    if force_clean
        for d in output_dirs
            all_files = getdir(d; dirs = false, files = true, absolute = true)
            # preserve log
            all_files = setdiff(all_files, "log.txt")
            for f in all_files
                rm(f; force = true)
            end
        end
    end

    if clear_logs
        for d in output_dirs
            rm(joinpath(d, "log.txt"); force = true)
        end
    end

    # determine which jobs to run

    indices_to_execute = Int64[]

    for (idx, d) in enumerate(output_dirs)
        if !isfile(joinpath(d, "out.jld2"))
            push!(indices_to_execute, idx)
        end
    end

    threads = Task[]

    if !isempty(indices_to_execute)

        if !isinf(progress_freq_sec)
            # launch thread doing the progress reports
            mark_finish = Channel{Bool}()
            Threads.@spawn :interactive _display_progress(mark_finish, output_dirs[indices_to_execute]; progress_freq_sec)
        end

        # launch all other threads
        for idx in indices_to_execute        
            push!(threads, Threads.@spawn :default _local_parexec(f, p[idx], output_dirs[idx]))
        end
    
        # wait for all to finish
        for thread in threads
            wait(thread)
        end

        if !isinf(progress_freq_sec)
            put!(mark_finish, true)
            close(mark_finish)
        end
        
    end

    has_no_output = [ idx for idx in 1:length(output_dirs) if !isfile(joinpath(output_dirs[idx],"out.jld2")) ]

    if print_log_of_failed_jobs && length(has_no_output) > 0
        println()
        println("$(length(has_no_output)) job(s) failed. Logs:")
        println()
        for idx in has_no_output
            println( joinpath(output_dirs[idx]), ":" )
            println()
            open(joinpath( output_dirs[idx], "log.txt"), "r") do file
                println(String(read(file)))
            end
        end
    end

    # collect results
    return [ isfile(joinpath(d,"out.jld2")) ?  load(joinpath(d,"out.jld2"),"result") : nothing for d in output_dirs ], output_dirs, has_no_output

end


# the function that runs in the threaded / distributed instance
function _local_parexec(f::Function, p::T, dir::String) where T <: AbstractParameters

    mkpath(dir)

    open(joinpath( dir, string(typeof(p)) * ".params"), "w") do file
        write(file, string(p))
    end

    logger = FormatLogger(open( joinpath(dir, "log.txt"), "a")) do io, args
        println(io, args._module, " | ", now(), " [", args.level, "] ", args.message)
    end
    
    with_logger(logger) do
        try
            # call the function
            _prrep(progress::Float64) = _local_progressrep(progress::Float64, dir)
            res = f(p, dir, _prrep)
            save( joinpath(dir, "out.jld2"), "result", res)
        catch err
            @error withtrace(err, "job failed:")
            _local_progressrep(-1, dir)
        end
    end
    
end


function _local_progressrep(progress::Number, dir::String)

    open(joinpath( dir, "progress.txt"), "w"; lock = true) do file
        write(file, Float64(progress))
    end

end


function _display_progress(mark_finish::Channel, dirs::Vector{String}; progress_freq_sec::Float64)

    prs = zeros(length(dirs))

    total_pbar = Progress(100; desc = "$(length(dirs))⌛")

    failed_job_indices = Set{Int64}()
    prev_num_failed_jobs = 0

    try

        while true

            # refresh progress
            for (idx,d) in enumerate(dirs)
                prfile = joinpath(d, "progress.txt")
                if prs[idx] != 1 && isfile(prfile)
                    try 
                        open(joinpath( d, "progress.txt"), "r") do file
                            prs[idx] = read(file, Float64)
                        end
                    catch _
                    end
                end
            end

            num_waiting_jobs = count(prs .== 0)
            num_running_jobs = count(prs .> 0 .&& prs .< 1)
            num_finished_jobs = count(prs .== 1)
            num_failed_jobs = count(prs .== -1)

            if prev_num_failed_jobs < num_failed_jobs
                println()
                new_failed_jobs = setdiff(findall(prs .== -1), failed_job_indices)
                for idx in new_failed_jobs
                    printstyled("job failed: $(dirs[idx])\n"; color = :light_red)
                end
                failed_job_indices = union(failed_job_indices, new_failed_jobs)
            end

            total_progress_goal = length(dirs) - num_failed_jobs
            total_progress = sum(prs[ prs .!= -1 ])

            desc =
                (num_waiting_jobs > 0 ? "$(num_waiting_jobs)⌛" : "") *
                (num_running_jobs > 0 ? "$(num_running_jobs)⏩" : "") *
                (num_finished_jobs > 0 ? "$(num_finished_jobs)✅" : "") *
                (num_failed_jobs > 0 ? "$(num_failed_jobs)❌" : "")
            
            ProgressMeter.update!(total_pbar, Int64(round(100 * total_progress / total_progress_goal)); desc)

            prev_num_failed_jobs = num_failed_jobs

            # quit if told
            if isready(mark_finish)
                take!(mark_finish)
                finish!(total_pbar)
                return
            end

            sleep(progress_freq_sec)
        end

    catch err
        @error withtrace(err, "bug in progress report thread, please report:")
    end

end
