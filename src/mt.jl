function clear_current_task()
    current_task().storage = nothing
    current_task().code = nothing
    return
end

"""
    @sp [:default|:interactive] expr

Enhanced Task spawning:

 - ensures the GC can truly free finished tasks by releasing .storage and .code.
 
 - uses Threads.errormonitor() to get output on task errors. That one runs another
 Task conditional on this one finishing, and examines if the task failed.

Create a `Task` and `schedule` it to run on any available
thread in the specified threadpool (`:default` if unspecified). The task is
allocated to a thread once one becomes available. To wait for the task to
finish, call `wait` on the result of this macro, or call
`fetch` to wait and then obtain its return value.

Values can be interpolated into `@wkspawn` via `\$`, which copies the value
directly into the constructed underlying closure. This allows you to insert
the _value_ of a variable, isolating the asynchronous code from changes to
the variable's value in the current task.
"""
macro sp(args...)
    e = args[end]
    expr = quote
        ret = $e
        $(clear_current_task)()
        ret
    end
@static if isdefined(Base.Threads, :maxthreadid)
    q = esc(:(Threads.errormonitor(Threads.@spawn $(args[1:end-1]...) $expr)))
else
    q = esc(:(Threads.errormonitor(Threads.@spawn $expr)))
end
    return q
end