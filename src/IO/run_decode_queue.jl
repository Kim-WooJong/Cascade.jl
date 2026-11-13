"""Supervised bounded ordinal window with an independent fatal/cancel condition.

Payload credits survive completion until ordered assembly. A higher decode error
still permits lower frontier assembly, so the lowest admitted scientific failure
wins. Lifecycle fatals/cancellation abort admission and settle every created task.
Test hooks are internal seams, not user decoder plugins.
"""
function run_decode_queue(charges,prepare,decoder,assemble;actors,max_jobs,max_bytes,
        diagnostics=Dict{String,Any}(),cancelled=()->false,
        worker_hook=(stage,k)->nothing,spawn_hook=(stage,k,task)->nothing,
        controller_hook=(stage,value)->nothing,cleanup_hook=()->nothing)
    actors>=2 && max_jobs>=1 && max_bytes>=1 || throw(ArgumentError("invalid decode queue budget"))
    all(c->0<=c<=max_bytes,charges) || error("decode job exceeds queue byte budget")
    n=length(charges);n==0 && return nothing
    width=min(actors-1,max_jobs,n)
    guard=ReentrantLock()
    state=DecodeQueueState(guard,Threads.Condition(guard),Threads.Condition(guard),Any[],Dict{Int,Any}(),Any[],false,false,false,0,0)
    sizehint!(state.input,min(max_jobs,n));sizehint!(state.fatals,width)
    workers=Vector{Task}(undef,width);starts=Vector{Base.Event}(undef,width);created=0
    credits=Dict{Int,Int}();pending=Dict{Int,Any}();errors=Dict{Int,Any}()
    livebytes=0;next=1;frontier=1;stopped=false;wascancelled=false
    primary=nothing;cleanup_errors=Any[];reserved=0;released=0
    reserved_bytes=Int128(0);released_bytes=Int128(0)
    try
        controller_hook(:ready,state)
        for slot in 1:width
            spawn_hook(:before_create,slot,nothing)
            start=Base.Event();starts[slot]=start
            # Public default-pool scheduling; startup is inside worker supervision.
            # Retain the returned task before releasing its nonblocking event.
            task=Base.disable_sigint() do
                t=Threads.@spawn :default decode_worker_loop($state,$decoder,$worker_hook,$start)
                workers[slot]=t;created=slot
                t
            end
            spawn_hook(:before_start,slot,task)
            notify(start)
            spawn_hook(:after_start,slot,task)
        end
        while !isempty(credits) || (!stopped && next<=n)
            status=lock(guard) do
                (state.cancelled,isempty(state.fatals) ? nothing : first(state.fatals),state.stopping)
            end
            if status[1] || cancelled()
                wascancelled=true;cancel_decode_queue!(state);break
            elseif status[2]!==nothing
                e,bt,k=status[2];primary=(DecodeWorkerError(e,bt,k),bt);break
            end
            stopped |= status[3]
            while !stopped && next<=n && length(credits)<max_jobs && charges[next]<=max_bytes-livebytes
                k=next;next+=1;charge=charges[k]
                credits[k]=charge;livebytes+=charge;reserved+=1;reserved_bytes+=charge
                diagnostics["queue_jobs_highwater"]=max(get(diagnostics,"queue_jobs_highwater",0),length(credits))
                diagnostics["queue_bytes_highwater"]=max(get(diagnostics,"queue_bytes_highwater",0),livebytes)
                job=nothing;prepared=false
                try
                    job=prepare(k);prepared=true
                catch e
                    if e isa InterruptException
                        wascancelled=true;cancel_decode_queue!(state)
                    else
                        errors[k]=(e,catch_backtrace());pending[k]=nothing
                    end
                    stopped=true
                end
                if prepared
                    # Enqueue/bookkeeping failures are controller failures, not
                    # fake preparation errors for a possibly already queued job.
                    lock(guard) do
                        push!(state.input,(k,job));notify(state.work_ready)
                    end
                end
                job=nothing
                controller_hook(:after_admit,k)
                ready=lock(guard) do
                    state.stopping || !isempty(state.completed) || !isempty(state.fatals)
                end
                (ready || wascancelled) && break
            end
            wascancelled && break
            if !haskey(pending,frontier) && !isempty(credits)
                controller_hook(:before_wait,frontier)
                event=lock(guard) do
                    while isempty(state.completed) && isempty(state.fatals) && !state.cancelled
                        wait(state.ready)
                    end
                    if state.cancelled
                        (:cancel,nothing)
                    elseif !isempty(state.fatals)
                        (:fatal,first(state.fatals))
                    else
                        k=haskey(state.completed,frontier) ? frontier : minimum(keys(state.completed))
                        (:result,(k,pop!(state.completed,k)))
                    end
                end
                if event[1]===:cancel
                    wascancelled=true;break
                elseif event[1]===:fatal
                    e,bt,k=event[2];primary=(DecodeWorkerError(e,bt,k),bt);break
                else
                    k,(result,failure,seconds,allocations)=event[2]
                    pending[k]=result;result=nothing;event=nothing
                    diagnostics["decode_task_seconds"]=get(diagnostics,"decode_task_seconds",0.0)+seconds
                    diagnostics["max_job_seconds"]=max(get(diagnostics,"max_job_seconds",0.0),seconds)
                    diagnostics["decode_allocated_bytes"]=get(diagnostics,"decode_allocated_bytes",0)+allocations
                    diagnostics["max_job_allocated_bytes"]=max(get(diagnostics,"max_job_allocated_bytes",0),allocations)
                    if failure!==nothing
                        errors[k]=failure;stopped=true
                    end
                end
            end
            while haskey(pending,frontier)
                result=pop!(pending,frontier)
                if isempty(errors) || frontier<minimum(keys(errors))
                    try
                        assemble(frontier,result)
                    catch e
                        if e isa InterruptException
                            wascancelled=true;cancel_decode_queue!(state)
                        else
                            errors[frontier]=(e,catch_backtrace())
                        end
                        stopped=true
                    end
                end
                result=nothing
                charge=pop!(credits,frontier);livebytes-=charge;released+=1;released_bytes+=charge;frontier+=1
                wascancelled && break
            end
            wascancelled && break
        end
    catch e
        primary=(e,catch_backtrace())
    finally
        lock(guard) do
            state.shutdown=true;state.stopping=true
            empty!(state.input)
            notify(state.ready;all=true);notify(state.work_ready;all=true)
        end
        for slot in 1:created
            task=workers[slot]
            try
                # Idempotent Event notification cannot block even if normal start
                # already happened. Partially started tasks see shutdown only.
                notify(starts[slot])
                wait(task)
            catch e
                push!(cleanup_errors,e)
            end
        end
        result=nothing;event=nothing;job=nothing;failure=nothing
        empty!(pending)
        for charge in values(credits)
            released+=1;released_bytes+=charge
        end
        empty!(credits);livebytes=0
        lock(guard) do
            # A worker can fail AFTER its last result was consumed. Join first,
            # then inspect control state before dropping any fatal notification.
            if primary===nothing
                if state.cancelled
                    wascancelled=true
                elseif !isempty(state.fatals)
                    e,bt,k=first(state.fatals);primary=(DecodeWorkerError(e,bt,k),bt)
                end
            end
            empty!(state.input);empty!(state.completed);empty!(state.fatals)
        end
        try cleanup_hook() catch e;push!(cleanup_errors,e);end
        merge!(diagnostics,Dict("workers_joined"=>all(istaskdone,workers[1:created]),
            "created_workers"=>created,"tasks_done"=>all(istaskdone,workers[1:created]),
            "active_decoders_final"=>state.active,"live_jobs_final"=>length(credits),
            "live_bytes_final"=>livebytes,"retained_payloads_final"=>length(state.input)+length(state.completed)+length(pending),
            "credits_reserved"=>reserved,"credits_released"=>released,
            "bytes_reserved"=>reserved_bytes,"bytes_released"=>released_bytes,
            "cleanup_errors"=>length(cleanup_errors)))
        diagnostics["max_active_decoders"]=max(get(diagnostics,"max_active_decoders",0),state.maxactive)
        diagnostics["decoder_workers"]=max(get(diagnostics,"decoder_workers",0),created)
        diagnostics["effective_actors"]=max(get(diagnostics,"effective_actors",1),created+1)
    end
    primary===nothing || throw(first(primary))
    wascancelled && throw(InterruptException())
    if !isempty(errors)
        k=minimum(keys(errors));e,bt=errors[k];throw(DecodeJobError(k,e,bt))
    end
    isempty(cleanup_errors) || throw(first(cleanup_errors))
    return nothing
end
