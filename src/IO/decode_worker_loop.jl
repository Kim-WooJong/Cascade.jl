"""Supervise the entire worker lifecycle, not only the decoder callback.

Fatal notification uses guarded state plus a condition, never result capacity.
Hooks are internal synthetic tests; no asynchronous native interruption occurs.
"""
function decode_worker_loop(state::DecodeQueueState, decoder, hook, start::Base.Event)
    ordinal = 0; job = nothing; result = nothing; timed = nothing; item = nothing
    active_owned = false
    try
        hook(:before_start_wait,ordinal)
        wait(start)
        while true
            hook(:before_input,ordinal)
            lock(state.guard)
            try
                while isempty(state.input) && !state.shutdown && !state.cancelled && isempty(state.fatals)
                    wait(state.work_ready)
                end
                (state.shutdown || state.cancelled || !isempty(state.fatals)) && break
                item = popfirst!(state.input)
            finally
                unlock(state.guard)
            end
            ordinal,job = item; item = nothing
            hook(:before_active,ordinal)
            lock(state.guard) do
                state.active += 1; active_owned = true
                state.maxactive = max(state.maxactive,state.active)
            end
            hook(:after_active,ordinal)
            failure = nothing; seconds = 0.0; allocations = 0
            hook(:before_decode,ordinal)
            try
                timed = @timed decoder(job)
                result = timed.value; seconds = timed.time; allocations = timed.bytes
            catch e
                if e isa InterruptException
                    lock(state.guard) do
                        state.cancelled = true; state.stopping = true
                        notify(state.ready;all=true);notify(state.work_ready;all=true)
                    end
                else
                    failure = (e,catch_backtrace())
                end
            finally
                lock(state.guard) do
                    state.active -= 1; active_owned = false
                end
            end
            hook(:after_decode,ordinal)
            job = nothing; timed = nothing
            hook(:before_publish,ordinal)
            lock(state.guard) do
                if !state.shutdown
                    state.completed[ordinal] = (result,failure,seconds,allocations)
                    failure === nothing || (state.stopping = true)
                    notify(state.ready;all=true)
                end
            end
            result = nothing; failure = nothing
            hook(:after_publish,ordinal)
        end
    catch e
        failure = (e,catch_backtrace(),ordinal)
        lock(state.guard) do
            if e isa InterruptException
                state.cancelled = true
            else
                push!(state.fatals,failure)
            end
            state.stopping = true
            notify(state.ready;all=true);notify(state.work_ready;all=true)
        end
    finally
        job = nothing; result = nothing; timed = nothing; item = nothing; failure = nothing
        lock(state.guard) do
            if active_owned
                state.active -= 1; active_owned = false
            end
            notify(state.ready;all=true)
        end
    end
    return nothing
end
