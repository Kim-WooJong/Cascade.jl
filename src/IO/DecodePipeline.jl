"""Borrowed invocation scope. Only the producer accesses original and identity."""
struct DecodePipeline
    original::NanoAODSource
    actors::Int
    jobs::Int
    bytes::Int
    identity::Any
    diagnostics::Dict{String,Any}
end

struct DecodeJobError <: Exception
    ordinal::Int
    exception::Any
    backtrace::Any
end
function Base.showerror(io::Base.IO, e::DecodeJobError)
    print(io, "decode job ", e.ordinal, " failed: ")
    showerror(io, e.exception, e.backtrace)
end

"""One lock/condition supervises bounded payloads and independent fatal wakeups."""
mutable struct DecodeQueueState
    guard::ReentrantLock
    ready::Threads.Condition
    work_ready::Threads.Condition
    input::Vector{Any}
    completed::Dict{Int,Any}
    fatals::Vector{Any}
    stopping::Bool
    shutdown::Bool
    cancelled::Bool
    active::Int
    maxactive::Int
end

struct DecodeWorkerError <: Exception
    exception::Any
    backtrace::Any
    ordinal::Int
end
function Base.showerror(io::Base.IO,e::DecodeWorkerError)
    print(io,"decode worker lifecycle failed at ordinal ",e.ordinal,": ")
    showerror(io,e.exception,e.backtrace)
end

"""Cooperative cancellation wakes the controller and input waiters, never native code."""
function cancel_decode_queue!(state::DecodeQueueState)
    lock(state.guard) do
        state.cancelled = true; state.stopping = true
        notify(state.ready;all=true);notify(state.work_ready;all=true)
    end
    return nothing
end
