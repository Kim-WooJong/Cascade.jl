"""
    batch_worker(workdir, task_id) -> Dict

Run one frozen file task in an isolated attempt. OS locks prevent duplicate
claims and release on interruption. Only a verified receipt publishes success.
Call through the worker CLI for fresh-process isolation.
"""
function batch_worker(workdir, task_id)
    work = abspath(workdir)
    m, cfg = batch_load(work; task_id)
    matches = [t for t in m["tasks"] if t["id"] == task_id]
    length(matches) == 1 || throw(ArgumentError("unknown task ID: $task_id"))
    task = only(matches)
    return batch_lock(joinpath(work, "locks", task_id * ".lock")) do
        prior = try batch_receipt(work, m, cfg, task) catch; nothing end
        prior === nothing || return Dict("status" => "reused", "task" => task_id)
        parent = batch_safe_path(joinpath(work, "attempts", task_id); root = work); mkpath(parent)
        attempt = mktempdir(parent; prefix = "attempt-", cleanup = false)
        artifacts = joinpath(attempt, "artifacts"); mkpath(artifacts)
        state = Dict("manifest" => m["id"], "task" => task_id, "pid" => getpid(), "status" => "running")
        batch_atomic_json(joinpath(attempt, "state.json"), state)
        logpath = joinpath(attempt, "worker.log")
        try
            name = task["sample"]
            skim = deepcopy(m["skims"][name]); skim["files"] = [task["entry"]]
            scope = if haskey(task["entry"], "group_id")
                group = only(g for g in skim["groups"] if g["group_id"] == task["entry"]["group_id"])
                skim["groups"] = [group]
                Dict("group" => group, "entry" => task["entry"])
            else
                nothing
            end
            batch_atomic_json(skim_path(artifacts, name), skim)
            opts = RunOptions(m["config"]; profile = m["profile"], workdir = artifacts, force = true)
            samples = [batch_task_sample(sample_by_name(cfg, name), task["entry"]["path"])]
            open(logpath, "w") do log
                redirect_stdout(log) do
                    redirect_stderr(log) do
                        for step in (:select, :correct, :histogram)
                            run_step(step, StepContext(cfg, artifacts, step, samples, opts, scope))
                        end
                    end
                end
            end
            batch_load(work; task_id) # Recheck source/payload/input drift before publication.
            receipt = Dict("manifest" => m["id"], "task" => task_id,
                "fingerprint" => batch_hash(m["fingerprint"]), "attempt" => basename(attempt),
                "files" => batch_files(artifacts))
            candidate = batch_atomic_json(joinpath(attempt, "receipt.json"), receipt)
            batch_receipt(work, m, cfg, task; path = candidate)
            batch_atomic_json(joinpath(work, "receipts", task_id * ".json"), receipt)
            state["status"] = "complete"
            batch_atomic_json(joinpath(attempt, "state.json"), state)
            return Dict("status" => "complete", "task" => task_id)
        catch e
            state["status"] = "failed"; state["error"] = sprint(showerror, e, catch_backtrace())
            batch_atomic_json(joinpath(attempt, "state.json"), state)
            open(logpath, "a") do log
                println(log, state["error"])
            end
            rethrow()
        end
    end
end
