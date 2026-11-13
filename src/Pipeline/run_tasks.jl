"""
    run_tasks(f, items; label = "") -> Vector

Apply `f` to every item on `Threads.nthreads()` worker tasks (dynamic load
balancing). Results keep the item order. All items are attempted; if any
failed, the errors are printed and an exception is thrown after the others
finished (completed chunks keep their artifacts, so a rerun redoes only failures).
"""
function run_tasks(f, items::AbstractVector; label::AbstractString = "")
    n = length(items)
    results = Vector{Any}(undef, n)
    errors = Vector{Any}(nothing, n)
    next = Threads.Atomic{Int}(1)
    done = Threads.Atomic{Int}(0)
    t0 = time()
    step = max(1, n ÷ 20)
    @sync for _ in 1:min(Threads.nthreads(), n)
        Threads.@spawn while true
            k = Threads.atomic_add!(next, 1)
            k > n && break
            try
                results[k] = f(items[k])
            catch e
                errors[k] = (e, catch_backtrace())
            end
            d = Threads.atomic_add!(done, 1) + 1
            if !isempty(label) && (d % step == 0 || d == n)
                println("  [", label, "] ", d, "/", n, " (", round(time() - t0; digits = 1), " s)")
                flush(stdout)
            end
        end
    end
    failed = findall(!isnothing, errors)
    if !isempty(failed)
        for k in failed[1:min(end, 3)]
            e, bt = errors[k]
            println(stderr, "task ", k, " failed: ", sprint(showerror, e, bt; context = :limit => true))
        end
        error("$(length(failed)) of $n $(label) tasks failed")
    end
    return results
end
