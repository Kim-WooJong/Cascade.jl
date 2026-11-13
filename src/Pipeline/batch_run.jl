"""
    batch_run(workdir; workers=nothing) -> Dict

Resume locally using bounded fresh Julia processes. Only verified receipts are
reused; all missing/invalid tasks are attempted once. Failures retain logs and
produce a nonzero CLI exit. Worker count does not change the frozen task set.
"""
function batch_run(workdir; workers = nothing)
    work = abspath(workdir); m, _ = batch_load(work)
    count = workers === nothing ? Int(m["workers"]) : workers
    count isa Integer && !(count isa Bool) && count > 0 || throw(ArgumentError("workers must be positive"))
    return batch_lock(joinpath(work, "locks", "coordinator.lock")) do
        status = batch_status(work)
        isempty(status["extra_receipts"]) || error("unexpected receipt inventory")
        pending = [t for t in m["tasks"] if status["tasks"][t["id"]]["status"] != "verified"]
        # Reject an unsafe pending task before launching any member of a group.
        for t in pending
            for path in (joinpath(work, "attempts", t["id"]), joinpath(work, "launches", t["id"]),
                joinpath(work, "locks", t["id"] * ".lock"), joinpath(work, "receipts", t["id"] * ".json"))
                batch_safe_path(path; root = work)
            end
        end
        failures = String[]
        for start in 1:count:length(pending)
            group = pending[start:min(start + count - 1, length(pending))]
            children = Any[]
            for t in group
                logdir = batch_safe_path(joinpath(work, "launches", t["id"]); root = work); mkpath(logdir)
                path, log = mktemp(logdir; cleanup = false)
                cmd = batch_command(work, t["id"], Int(m["threads"]))
                proc = run(pipeline(ignorestatus(cmd); stdout = log, stderr = log); wait = false)
                push!(children, (t, proc, log, path))
            end
            for (t, proc, log, path) in children
                wait(proc); close(log)
                batch_atomic_json(path * ".exit.json", Dict("exitcode" => proc.exitcode, "task" => t["id"]))
                success(proc) || push!(failures, t["id"])
            end
        end
        result = batch_status(work)
        if !isempty(failures) || !result["complete"]
            println(stderr, JSON3.write(result))
            error("batch incomplete; failed tasks: $(join(failures, ',')); see attempts/ and launches/ logs")
        end
        return result
    end
end
