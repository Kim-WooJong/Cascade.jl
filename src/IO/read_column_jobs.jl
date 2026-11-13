"""Run bounded dynamic branch jobs; join all readers and assemble in input order."""
function read_column_jobs(scope::ColumnReadScope, jobs, needed)
    width = min(scope.width, length(jobs))
    while length(scope.slots) < width
        slot = scope.opener()
        push!(scope.slots, slot)
        scope.diagnostics["extra_opens"] += 1
    end
    scope.diagnostics["effective_readers"] = max(scope.diagnostics["effective_readers"], width)
    scope.diagnostics["fallback"] = ""
    scope.diagnostics["branch_jobs"] += length(jobs)
    results = Vector{Any}(undef, length(jobs))
    errors = Vector{Any}(nothing, length(jobs))
    next = Threads.Atomic{Int}(1)
    @sync for slot in scope.slots[1:width]
        Threads.@spawn while true
            k = Threads.atomic_add!(next, 1)
            k > length(jobs) && break
            lock(scope.lock) do
                scope.active += 1
                scope.diagnostics["max_active_reads"] = max(scope.diagnostics["max_active_reads"], scope.active)
            end
            try
                name, offsets = jobs[k]
                results[k] = scope.readbranch(slot, name, needed, offsets)
            catch e
                errors[k] = e
            finally
                lock(scope.lock) do
                    scope.active -= 1
                end
            end
        end
    end
    failed = findfirst(!isnothing, errors)
    failed === nothing || throw(errors[failed])
    out = Dict{String,Any}()
    for (job, value) in zip(jobs, results)
        out[first(job)] = value
    end
    return out
end
