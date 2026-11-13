"""Stage-global dynamic default-pool jobs, not per-file permanent workers.

Each file has one serialized reader and one ordered analysis continuation. Two
window credits include queued, running and completed payloads. Fatal/cancel
notifications use the proven independent worker control path, never a channel
which could be full. Sources close only after their jobs settle, or global join.
"""
function run_window_pipeline(items, opener, reader, analyzer, publisher, closer;
        options, diagnostics=Dict{String,Any}(), actors=Threads.nthreads(),
        cancelled=()->false, worker_hook=(stage,k)->nothing,
        spawn_hook=(stage,k,task)->nothing, controller_hook=(stage,value)->nothing, waiter=wait)
    2<=actors<=Threads.nthreads() || throw(ArgumentError("stream pool needs at least two actors"))
    if isempty(items)
        merge!(diagnostics,Dict("workers_joined"=>true,"created_workers"=>0,"active_workers_final"=>0,
            "live_windows_final"=>0,"live_bytes_final"=>0,"retained_bytes_final"=>0,"credits_reserved"=>0,
            "credits_released"=>0,"bytes_reserved"=>0,"bytes_released"=>0,"completed_files"=>0))
        return Any[]
    end
    g=ReentrantLock()
    state=EventIO.DecodeQueueState(g,Threads.Condition(g),Threads.Condition(g),Any[],Dict{Int,Any}(),Any[],false,false,false,0,0)
    width=min(actors-1,options.stream_queue_windows)
    workers=Task[];starts=Base.Event[];files=Dict{Int,Any}();jobs=Dict{Int,Any}()
    nextfile=1;nextjob=1;windowbytes=0;metadata=0;retained=0;retainreserved=0
    reserved=0;released=0;reservedbytes=Int128(0);releasedbytes=Int128(0)
    errors=Dict{Int,Any}();fallbacks=Any[];primary=nothing;cleanup=Any[];complete=0
    function release_window!(f,k)
        charge=pop!(f.credits,k);windowbytes-=charge;released+=1;releasedbytes+=charge
    end
    function submit!(fi,kind,k,payload=nothing)
        f=files[fi];id=nextjob;nextjob+=1
        # Analysis closures capture only the detached analysis state and payload.
        target=kind===:read ? f.data.reader : f.data.analysis
        callback=kind===:read ? reader : analyzer
        run=let target=target,payload=payload,k=k,callback=callback,kind=kind
            ()->begin
                t0=time_ns()
                value=kind===:read ? callback(target,k) : callback(target,payload,k)
                (value=value,begin_ns=t0,end_ns=time_ns())
            end
        end
        jobs[id]=(file=fi,kind=kind,window=k)
        if kind===:read
            f.readbusy=true
        else
            f.analysebusy=true
            charge=f.data.retained_charges[k];retainreserved+=charge
            f.retainreservation=charge
        end
        lock(g) do
            push!(state.input,(id,run));notify(state.work_ready)
        end
        return nothing
    end
    try
        controller_hook(:ready,state)
        for slot in 1:width
            spawn_hook(:before_create,slot,nothing)
            start=Base.Event();push!(starts,start)
            task=Base.disable_sigint() do
                t=Threads.@spawn :default EventIO.decode_worker_loop($state,job->job(),$worker_hook,$start)
                push!(workers,t)
                t
            end
            spawn_hook(:before_start,slot,task);notify(start);spawn_hook(:after_start,slot,task)
        end
        while nextfile<=length(items) || !isempty(files) || !isempty(jobs)
            cancelled() && throw(InterruptException())
            lock(g) do
                state.cancelled && throw(InterruptException())
                if !isempty(state.fatals)
                    e,bt,k=first(state.fatals);throw(EventIO.DecodeWorkerError(e,bt,k))
                end
            end
            progress=false
            # First consume every completed message. Credits remain until analysis
            # consumes a payload, including results which completed out of order.
            completed=lock(g) do
                x=collect(state.completed);empty!(state.completed);x
            end
            for (id,(result,failure,seconds,allocations)) in completed
                j=pop!(jobs,id);f=files[j.file];k=j.window
                if j.kind===:read
                    f.readbusy=false
                else
                    f.analysebusy=false;retainreserved-=f.retainreservation
                    if failure!==nothing
                        # Failed callback may have appended partial selected output.
                        # Keep its entire reservation until the file is discarded.
                        retained+=f.retainreservation;f.retained+=f.retainreservation
                    end
                    f.retainreservation=0
                end
                if failure!==nothing
                    # A later read may fail before an earlier analysis settles.
                    # Preserve the lowest original-entry window's real failure.
                    if k<f.errorwindow
                        errors[j.file]=failure;f.errorwindow=k
                    end
                    f.failed=true
                elseif !f.failed
                    if j.kind===:read
                        f.ready[k]=result.value;f.readtimes[k]=(result.begin_ns,result.end_ns)
                    else
                        newretained=Int(result.value)
                        newretained>=f.retained || error("stream retained accounting regressed")
                        newretained-f.retained<=f.data.retained_charges[k] || error("stream retained reservation exceeded")
                        retained+=newretained-f.retained;f.retained=newretained
                        f.analysetimes[k]=(result.begin_ns,result.end_ns);f.nextanalyse+=1
                        release_window!(f,k)
                    end
                end
                result=nothing;failure=nothing;progress=true
            end
            # Drop the transferred/discarded result envelopes before returning
            # their credits or admitting another file/window.
            empty!(completed)
            for fi in sort!(collect(keys(files)))
                f=files[fi]
                if f.failed && !f.readbusy && !f.analysebusy
                    empty!(f.ready)
                    for k in collect(keys(f.credits));release_window!(f,k);end
                    retained-=f.retained;metadata-=options.stream_metadata_bytes
                    try closer(f.data) catch e;push!(cleanup,e);end
                    delete!(files,fi);progress=true
                elseif !f.failed && f.nextanalyse>length(f.data.windows) && !f.readbusy && !f.analysebusy
                    try
                        controller_hook(:before_publish,fi)
                        publisher(f.data,f.readtimes,f.analysetimes)
                        complete+=1
                    catch e
                        e isa InterruptException && rethrow()
                        errors[fi]=(e,catch_backtrace())
                    finally
                        try closer(f.data) catch e;push!(cleanup,e);end
                    end
                    retained-=f.retained;metadata-=options.stream_metadata_bytes
                    delete!(files,fi);progress=true
                end
            end
            while nextfile<=length(items) && length(files)<options.stream_active_files &&
                    Int128(metadata)+windowbytes+options.stream_metadata_bytes<=options.stream_queue_bytes
                fi=nextfile;nextfile+=1;metadata+=options.stream_metadata_bytes
                data=nothing
                try
                    data=opener(items[fi])
                    if data isa AbstractString
                        push!(fallbacks,(items[fi],String(data)));metadata-=options.stream_metadata_bytes
                    else
                        length(data.windows)==length(data.charges)==length(data.retained_charges) || error("stream plan cardinality mismatch")
                        all(c->0<c<=options.stream_queue_bytes-options.stream_metadata_bytes,data.charges) || error("stream window exceeds queue reservation")
                        files[fi]=WindowFileState(data)
                        data=nothing # ownership transferred; finally joins before closing
                    end
                catch e
                    e isa InterruptException && rethrow()
                    errors[fi]=(e,catch_backtrace());metadata-=options.stream_metadata_bytes
                    if data!==nothing && !(data isa AbstractString)
                        try closer(data) catch e;push!(cleanup,e);end
                    end
                end
                progress=true
            end
            # Analysis first: it frees credits and advances the file frontier.
            for fi in sort!(collect(keys(files)))
                f=files[fi];f.failed && continue;k=f.nextanalyse
                if !f.analysebusy && haskey(f.ready,k) &&
                        Int128(retained)+retainreserved+f.data.retained_charges[k]<=options.stream_retained_bytes
                    payload=pop!(f.ready,k);submit!(fi,:analysis,k,payload);payload=nothing;progress=true
                end
            end
            for fi in sort!(collect(keys(files)))
                f=files[fi];f.failed && continue;k=f.nextread
                if !f.readbusy && k<=length(f.data.windows) && length(f.credits)<2 &&
                        sum((length(x.credits) for x in values(files));init=0)<options.stream_queue_windows &&
                        Int128(metadata)+windowbytes+f.data.charges[k]<=options.stream_queue_bytes
                    charge=f.data.charges[k];f.credits[k]=charge;windowbytes+=charge
                    reserved+=1;reservedbytes+=charge;f.nextread+=1
                    submit!(fi,:read,k);progress=true
                    controller_hook(:after_admit,(fi,k))
                end
            end
            diagnostics["queue_windows_highwater"]=max(get(diagnostics,"queue_windows_highwater",0),sum((length(x.credits) for x in values(files));init=0))
            diagnostics["queue_bytes_highwater"]=max(get(diagnostics,"queue_bytes_highwater",0),metadata+windowbytes)
            diagnostics["retained_bytes_highwater"]=max(get(diagnostics,"retained_bytes_highwater",0),retained+retainreserved)
            diagnostics["active_files_highwater"]=max(get(diagnostics,"active_files_highwater",0),length(files))
            isempty(jobs) && !isempty(files) && !progress && error("stream reservation cannot advance; increase explicit queue/retained budget")
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
        primary=(e,catch_backtrace())
    finally
        lock(g) do
            state.shutdown=true;state.stopping=true;empty!(state.input)
            notify(state.ready;all=true);notify(state.work_ready;all=true)
        end
        for (task,start) in zip(workers,starts)
            # Release each startup latch once during cleanup. Interrupted joins
            # must retry this SAME task; no source can close while it still runs.
            notify(start)
            while !istaskdone(task)
                try waiter(task) catch e;push!(cleanup,e);end
            end
        end
        # Fatal may happen after the last published message. Inspect after join.
        lock(g) do
            if primary===nothing
                if state.cancelled || any(e->e isa InterruptException,cleanup)
                    primary=(InterruptException(),nothing)
                elseif !isempty(state.fatals)
                    e,bt,k=first(state.fatals);primary=(EventIO.DecodeWorkerError(e,bt,k),bt)
                end
            end
            empty!(state.input);empty!(state.completed);empty!(state.fatals)
        end
        empty!(jobs)
        for f in values(files)
            empty!(f.ready)
            for k in collect(keys(f.credits));release_window!(f,k);end
            try closer(f.data) catch e;push!(cleanup,e);end
        end
        empty!(files);windowbytes=0;metadata=0;retained=0;retainreserved=0
        merge!(diagnostics,Dict("workers_joined"=>all(istaskdone,workers),"created_workers"=>length(workers),
            "max_active_workers"=>state.maxactive,"active_workers_final"=>state.active,
            "live_windows_final"=>0,"live_bytes_final"=>windowbytes+metadata,"retained_bytes_final"=>retained,
            "credits_reserved"=>reserved,"credits_released"=>released,"bytes_reserved"=>reservedbytes,
            "bytes_released"=>releasedbytes,"cleanup_errors"=>length(cleanup),"completed_files"=>complete))
    end
    primary===nothing || throw(first(primary))
    if !isempty(errors)
        fi=minimum(keys(errors));e,bt=errors[fi];throw(StreamFileError(fi,e,bt,fallbacks))
    end
    isempty(cleanup) || throw(first(cleanup))
    return fallbacks
end

mutable struct WindowFileState
    data::Any
    nextread::Int
    nextanalyse::Int
    readbusy::Bool
    analysebusy::Bool
    ready::Dict{Int,Any}
    credits::Dict{Int,Int}
    failed::Bool
    errorwindow::Int
    retained::Int
    retainreservation::Int
    readtimes::Dict{Int,Tuple{UInt64,UInt64}}
    analysetimes::Dict{Int,Tuple{UInt64,UInt64}}
end
WindowFileState(data)=WindowFileState(data,1,1,false,false,Dict{Int,Any}(),Dict{Int,Int}(),false,typemax(Int),0,0,
    Dict{Int,Tuple{UInt64,UInt64}}(),Dict{Int,Tuple{UInt64,UInt64}}())

"""Ordinary file failure after every stream job settles; keep deferred inventory."""
struct StreamFileError <: Exception
    ordinal::Int
    exception::Any
    backtrace::Any
    fallbacks::Vector{Any}
end
function Base.showerror(io::Base.IO,e::StreamFileError)
    print(io,"stream file ",e.ordinal," failed: ")
    showerror(io,e.exception,e.backtrace)
end
