"""
    OrderedWindow(f, items; window, workers, label = "")

Bounded ordered producer for the no-checkpoint route. Up to `workers` tasks apply
`f` to `items` claimed strictly in item order; at most `window` items may be
claimed but not yet taken by the single consumer (`take_next!`), so at most
`window` results (plus in-flight work) are alive at any time. Results are taken
in exact item order, independent of scheduling. The first failure stops new
claims; in-flight items finish, and `take_next!` rethrows that failure (fail
fast, no retry, no partial completion). Always call `shutdown_window!` (in `finally`)
so no worker outlives its consumer.

Failure semantics are schedule-first, not item-order-first: the rethrown error is
the first one RECORDED by any worker, which may belong to a later item than one
still in flight or not yet consumed, so the reported item can vary between runs
with the same inputs. Results already taken were merged only into in-memory state
that is discarded (nothing is published). The worker backtrace is printed to
stderr as "task <k> (<label>) failed: ..."; the rethrown exception object does not
carry it (`throw(e)` on the consumer task).

Each worker invocation owns its payloads; only `f`'s return value crosses to the
consumer. No thread ids are used; tasks may migrate.
"""
mutable struct OrderedWindow
    f::Any
    items::Vector{Any}
    window::Int
    lock::ReentrantLock
    cond::Threads.Condition
    ready::Dict{Int,Any}
    next_claim::Int
    next_take::Int
    failure::Any
    stopped::Bool
    alive::Int
    tasks::Vector{Task}
    max_retained::Int
    label::String
end

function OrderedWindow(f, items::AbstractVector; window::Integer, workers::Integer, label::AbstractString = "")
    window >= 1 || throw(ArgumentError("ordered window must be positive"))
    workers >= 1 || throw(ArgumentError("ordered window needs at least one worker"))
    lk = ReentrantLock()
    w = OrderedWindow(f, Vector{Any}(collect(items)), Int(window), lk, Threads.Condition(lk),
        Dict{Int,Any}(), 1, 1, nothing, false, 0, Task[], 0, String(label))
    n = min(Int(workers), length(w.items))
    w.alive = n
    for _ in 1:n
        push!(w.tasks, Threads.@spawn _ordered_window_worker(w))
    end
    return w
end

function _ordered_window_claim!(w::OrderedWindow)
    lock(w.lock) do
        while !w.stopped && w.failure === nothing && w.next_claim <= length(w.items) &&
                w.next_claim - w.next_take >= w.window
            wait(w.cond)
        end
        (w.stopped || w.failure !== nothing || w.next_claim > length(w.items)) && return 0
        k = w.next_claim
        w.next_claim += 1
        w.max_retained = max(w.max_retained, w.next_claim - w.next_take)
        return k
    end
end

function _ordered_window_worker(w::OrderedWindow)
    try
        while true
            k = _ordered_window_claim!(w)
            k == 0 && return nothing
            result = try
                w.f(w.items[k])
            catch e
                bt = catch_backtrace()
                lock(w.lock) do
                    w.failure === nothing && (w.failure = (k, e, bt))
                    notify(w.cond)
                end
                return nothing
            end
            lock(w.lock) do
                w.ready[k] = result
                notify(w.cond)
            end
        end
    finally
        lock(w.lock) do
            w.alive -= 1
            notify(w.cond)
        end
    end
end

"""
    take_next!(w::OrderedWindow) -> result of the next item in item order

Blocks until that result is available. Rethrows the first worker failure.
"""
function take_next!(w::OrderedWindow)
    failure = nothing
    result = lock(w.lock) do
        k = w.next_take
        k <= length(w.items) || throw(ArgumentError("ordered window $(w.label): no items left"))
        while w.failure === nothing && !haskey(w.ready, k) && w.alive > 0
            wait(w.cond)
        end
        if w.failure !== nothing
            failure = w.failure
            return nothing
        end
        haskey(w.ready, k) || error("ordered window $(w.label): workers exited before item $k")
        r = pop!(w.ready, k)
        w.next_take += 1
        notify(w.cond)
        return r
    end
    if failure !== nothing
        k, e, bt = failure
        println(stderr, "task ", k, " (", w.label, ") failed: ", sprint(showerror, e, bt; context = :limit => true))
        throw(e)
    end
    n = length(w.items); step = max(1, n ÷ 20); d = w.next_take - 1
    if !isempty(w.label) && (d % step == 0 || d == n)
        println("  [", w.label, "] ", d, "/", n); flush(stdout)
    end
    return result
end

"Stop claims, wake every worker and wait for all of them (idempotent)."
function shutdown_window!(w::OrderedWindow)
    lock(w.lock) do
        w.stopped = true
        notify(w.cond)
    end
    for t in w.tasks
        try
            wait(t)
        catch
            # Worker bodies capture their own failures; a scheduler-level failure
            # here must not mask the consumer's primary error.
        end
    end
    return nothing
end

"True when every item was taken and no failure occurred."
window_completed(w::OrderedWindow) = lock(() -> w.failure === nothing && w.next_take == length(w.items) + 1, w.lock)
