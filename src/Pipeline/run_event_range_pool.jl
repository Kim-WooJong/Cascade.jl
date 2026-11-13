"""An admitted file failed; deferred pre-read fallbacks remain available."""
struct EventRangeFileError <: Exception
    ordinal::Int
    exception::Any
    backtrace::Any
    fallbacks::Vector{Any}
end
function Base.showerror(io::Base.IO, e::EventRangeFileError)
    print(io, "event-range file ", e.ordinal, " failed: ")
    showerror(io, e.exception, e.backtrace)
end

mutable struct EventRangeFileState
    data::Any
    nextjob::Int
    nextmerge::Int
    running::Int
    ready::Dict{Int,Any}
    credits::Dict{Int,Int}
    retained::Int
    retained_required::Int
    failed::Bool
    errorrange::Int
end
EventRangeFileState(data, retained_required::Int) = EventRangeFileState(data, 1, 1, 0,
    Dict{Int,Any}(), Dict{Int,Int}(), 0, retained_required, false, typemax(Int))

function event_range_retained_reservation(charges, limit::Integer)
    total = Int128(0)
    for charge in charges
        charge isa Integer && !(charge isa Bool) && charge >= 0 ||
            error("invalid event-range retained charge")
        total = Base.checked_add(total,Int128(charge))
    end
    total <= limit && total <= typemax(Int) ||
        error("event-range complete file output exceeds stream_retained_bytes")
    return Int(total)
end

"""One stage-global pool: private read+selection jobs, single ordered merge owner.

Credits cover queued/running/completed raw, all-event ledger, private metadata
and reorder output until merge/discard. The complete checked per-file retained
output sum is reserved BEFORE its first job; other files defer rather than
fragmenting the budget into mutually unfinished partial tables.
No eager list of jobs or nested per-file worker pools. Only metadata opener may
return fallback strings. Callback errors propagate after join, never retry.
Cancellation is cooperative; all workers join before any file closes.
"""
function run_event_range_pool(items, opener, rangeopener, analyzer, merger, publisher,
        closer, rangecloser; options, diagnostics=Dict{String,Any}(),
        workers=Threads.nthreads(), cancelled=()->false,
        worker_hook=(stage,k)->nothing, controller_hook=(stage,value)->nothing,
        spawn_hook=(stage,k,task)->nothing, waiter=wait)
    !(workers isa Bool) && 1 <= workers <= Threads.nthreads() || throw(ArgumentError("invalid event-range worker count"))
    g = ReentrantLock()
    state = EventIO.DecodeQueueState(g, Threads.Condition(g), Threads.Condition(g),
        Any[], Dict{Int,Any}(), Any[], false, false, false, 0, 0)
    tasks = Task[]; starts = Base.Event[]
    files = Dict{Int,EventRangeFileState}(); jobs = Dict{Int,Any}()
    nextfile = 1; nextjob = 1; metadata = 0; livebytes = 0; retained = 0
    live = 0; admitted = 0; released = 0; completed_files = 0
    errors = Dict{Int,Any}(); fallbacks = Any[]; cleanup = Any[]; primary = nothing
    function release!(f, k)
        livebytes -= pop!(f.credits, k)
        live -= 1; released += 1
    end
    function submit!(fi, k, context)
        f = files[fi]; id = nextjob; nextjob += 1
        # Task-private closure; close exactly once even if lifecycle hooks fail.
        closed = Ref(false)
        closecontext = () -> begin
            if !closed[]
                closed[] = true
                rangecloser(context)
            end
        end
        run = () -> try
            analyzer(context, k)
        finally
            closecontext()
        end
        jobs[id] = (file=fi, range=k, close=closecontext); f.running += 1
        lock(g) do
            push!(state.input, (id, run)); notify(state.work_ready)
        end
    end
    try
        controller_hook(:ready, state)
        if !isempty(items)
            for slot in 1:min(workers, options.stream_queue_windows)
                spawn_hook(:before_create, slot, nothing)
                start = Base.Event(); push!(starts, start)
                task = Base.disable_sigint() do
                    t = Threads.@spawn :default EventIO.decode_worker_loop($state, job->job(), $worker_hook, $start)
                    push!(tasks, t)
                    t
                end
                spawn_hook(:before_start, slot, task); notify(start)
                spawn_hook(:after_start, slot, task)
            end
        end
        while nextfile <= length(items) || !isempty(files) || !isempty(jobs)
            options.stream_queue_bytes > 2Int128(options.stream_metadata_bytes) || error("event-range queue must leave private-reader and job capacity")
            cancelled() && throw(InterruptException())
            lock(g) do
                state.cancelled && throw(InterruptException())
                if !isempty(state.fatals)
                    e, bt, k = first(state.fatals)
                    throw(EventIO.DecodeWorkerError(e, bt, k))
                end
            end
            progress = false
            messages = lock(g) do
                x = collect(state.completed); empty!(state.completed); x
            end
            for (id, (result, failure, _, _)) in messages
                job = pop!(jobs, id); f = files[job.file]; k = job.range
                # Normal callbacks close before completion; lifecycle failures
                # remain registered until global join in the fatal path.
                f.running -= 1
                if failure !== nothing
                    f.failed = true
                    if k < f.errorrange
                        errors[job.file] = failure; f.errorrange = k
                    end
                elseif !f.failed
                    f.ready[k] = result
                end
                result = nothing; failure = nothing; job = nothing; progress = true
            end
            empty!(messages)
            for fi in sort!(collect(keys(files)))
                f = files[fi]
                if !f.failed
                    while haskey(f.ready, f.nextmerge)
                        k = f.nextmerge; payload = pop!(f.ready, k)
                        try
                            actual = merger(f.data, payload, k)
                            0 <= actual <= f.retained || error("event-range retained reservation exceeded")
                            f.nextmerge += 1
                        catch e
                            e isa InterruptException && rethrow()
                            errors[fi] = (e, catch_backtrace()); f.failed = true
                        finally
                            payload = nothing; release!(f, k)
                        end
                        progress = true
                        f.failed && break
                    end
                end
                if f.failed && f.running == 0
                    empty!(f.ready)
                    for k in collect(keys(f.credits)); release!(f,k); end
                    retained -= f.retained; metadata -= options.stream_metadata_bytes
                    try closer(f.data) catch e; push!(cleanup,e); end
                    delete!(files,fi); progress = true
                elseif !f.failed && f.nextmerge > length(f.data.windows) && f.running == 0
                    try
                        controller_hook(:before_publish,fi)
                        publisher(f.data); completed_files += 1
                    catch e
                        e isa InterruptException && rethrow()
                        errors[fi] = (e,catch_backtrace())
                    finally
                        try closer(f.data) catch e; push!(cleanup,e); end
                        # Remove ownership even when publisher is interrupted;
                        # global cleanup must not close this original twice.
                        retained -= f.retained; metadata -= options.stream_metadata_bytes
                        delete!(files,fi)
                    end
                    progress = true
                end
            end
            # Reserve a single metadata plan at a time, never the whole stage.
            # Keep room for a private reader and at least one runnable job.
            while nextfile <= length(items) && length(files) < options.stream_active_files &&
                    Int128(metadata)+livebytes+2Int128(options.stream_metadata_bytes) < options.stream_queue_bytes
                if !isempty(files)
                    largest = maximum(maximum(f.data.charges) for f in values(files))
                    Int128(metadata)+livebytes+largest+2Int128(options.stream_metadata_bytes) <= options.stream_queue_bytes || break
                end
                fi = nextfile; nextfile += 1; data = nothing
                try
                    data = opener(items[fi])
                    if data isa AbstractString
                        push!(fallbacks,(items[fi],String(data)))
                    else
                        length(data.windows) == length(data.charges) == length(data.retained_charges) ||
                            error("event-range plan cardinality mismatch")
                        isempty(data.windows) && error("event-range plan must include an empty window")
                        all(c -> 0 < c && Int128(c)+2Int128(options.stream_metadata_bytes) < options.stream_queue_bytes, data.charges) ||
                            error("event-range job exceeds queue reservation")
                        all(c -> 0 <= c <= options.stream_retained_bytes,data.retained_charges) ||
                            error("event-range output exceeds retained reservation")
                        required = event_range_retained_reservation(data.retained_charges,options.stream_retained_bytes)
                        files[fi] = EventRangeFileState(data,required)
                        metadata += options.stream_metadata_bytes; data = nothing
                    end
                catch e
                    e isa InterruptException && rethrow()
                    errors[fi] = (e,catch_backtrace())
                finally
                    if data !== nothing && !(data isa AbstractString)
                        try closer(data) catch e; push!(cleanup,e); end
                    end
                end
                progress = true
                # Prefer distinct files while leaving the largest admitted job
                # enough room; otherwise use the available tail range jobs.
                if !isempty(files)
                    largest = maximum(maximum(f.data.charges) for f in values(files))
                    Int128(metadata)+livebytes+largest+2Int128(options.stream_metadata_bytes) <= options.stream_queue_bytes || break
                end
                length(files) >= length(tasks) && break
            end
            # Round-robin one job/file/pass. Tail files use this SAME pool.
            dispatched = true
            while dispatched && live < min(length(tasks),options.stream_queue_windows)
                dispatched = false
                for fi in sort!(collect(keys(files)))
                    live >= min(length(tasks),options.stream_queue_windows) && break
                    f = files[fi]; k = f.nextjob
                    (f.failed || k > length(f.data.windows)) && continue
                    charge = f.data.charges[k]
                    Int128(metadata)+livebytes+charge+options.stream_metadata_bytes <= options.stream_queue_bytes || continue
                    if k == 1
                        Int128(retained)+f.retained_required <= options.stream_retained_bytes || continue
                        retained += f.retained_required
                        f.retained = f.retained_required
                    end
                    f.credits[k] = charge; livebytes += charge; live += 1; admitted += 1
                    f.nextjob += 1
                    context = nothing
                    try
                        context = rangeopener(f.data,k)
                        submit!(fi,k,context); context = nothing
                    catch e
                        e isa InterruptException && rethrow()
                        f.failed = true; errors[fi] = (e,catch_backtrace())
                    finally
                        if context !== nothing
                            try rangecloser(context) catch e; push!(cleanup,e); end
                        end
                    end
                    controller_hook(:after_admit,(fi,k))
                    progress = true; dispatched = true
                end
            end
            diagnostics["queue_windows_highwater"] = max(get(diagnostics,"queue_windows_highwater",0),live)
            diagnostics["queue_bytes_highwater"] = max(get(diagnostics,"queue_bytes_highwater",0),metadata+livebytes+(!isempty(files) ? options.stream_metadata_bytes : 0))
            diagnostics["retained_bytes_highwater"] = max(get(diagnostics,"retained_bytes_highwater",0),retained)
            diagnostics["active_files_highwater"] = max(get(diagnostics,"active_files_highwater",0),length(files))
            !progress && isempty(jobs) && (nextfile <= length(items) || !isempty(files)) && error("event-range reservation cannot advance; increase queue/retained budget")
            if !isempty(jobs)
                controller_hook(:before_wait,nothing)
                lock(g) do
                    while isempty(state.completed) && isempty(state.fatals) && !state.cancelled
                        wait(state.ready)
                    end
                end
            end
        end
    catch e
        primary = (e,catch_backtrace())
    finally
        lock(g) do
            state.shutdown = true; empty!(state.input)
            notify(state.work_ready;all=true); notify(state.ready;all=true)
        end
        for (task,start) in zip(tasks,starts)
            notify(start)
            while !istaskdone(task)
                try waiter(task) catch e; push!(cleanup,e); end
            end
        end
        lock(g) do
            if primary === nothing
                if state.cancelled || any(e->e isa InterruptException,cleanup)
                    primary = (InterruptException(),nothing)
                elseif !isempty(state.fatals)
                    e,bt,k = first(state.fatals)
                    primary = (EventIO.DecodeWorkerError(e,bt,k),bt)
                end
            end
            empty!(state.completed); empty!(state.fatals)
        end
        # Idempotent after JOIN: also closes unstarted and lifecycle-fatal jobs.
        for job in values(jobs)
            try job.close() catch e; push!(cleanup,e); end
        end
        empty!(jobs)
        for f in values(files)
            empty!(f.ready)
            for k in collect(keys(f.credits)); release!(f,k); end
            try closer(f.data) catch e; push!(cleanup,e); end
        end
        empty!(files)
        merge!(diagnostics,Dict("workers_joined"=>all(istaskdone,tasks),
            "created_workers"=>length(tasks),"max_active_workers"=>state.maxactive,
            "active_workers_final"=>state.active,"live_windows_final"=>0,
            "live_bytes_final"=>0,"retained_bytes_final"=>0,
            "credits_reserved"=>admitted,"credits_released"=>released,
            "completed_files"=>completed_files,"cleanup_errors"=>length(cleanup)))
    end
    primary === nothing || throw(first(primary))
    if !isempty(errors)
        fi = minimum(keys(errors)); e,bt = errors[fi]
        throw(EventRangeFileError(fi,e,bt,fallbacks))
    end
    isempty(cleanup) || throw(first(cleanup))
    return fallbacks
end
