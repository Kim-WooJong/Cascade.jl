"""
    batch_merge(workdir; steps=[:merge,:systematics]) -> String

Validate every expected task, stage chunks in frozen serial order, run global
normalization/theory and optional fit/plot, then atomically publish result/.
Existing verified identical final results are reused, never overwritten blindly.
"""
function batch_merge(workdir; steps = [:merge, :systematics])
    steps in ([:merge], [:merge, :systematics], [:merge, :systematics, :fit],
        [:merge, :systematics, :fit, :plot]) || throw(ArgumentError("merge steps must be a global phase prefix"))
    work = abspath(workdir); m, cfg = batch_load(work)
    return batch_lock(joinpath(work, "locks", "coordinator.lock")) do
        status = batch_status(work)
        status["complete"] || error("cannot merge missing, corrupt, extra or foreign tasks")
        result = joinpath(work, "result")
        if ispath(result)
            r = _jsdict(JSON3.read(read(joinpath(result, "batch-result.json"), String)))
            r["manifest"] == m["id"] && r["steps"] == String.(steps) || error("foreign final result/phase request")
            files = batch_files(result); delete!(files, "batch-result.json")
            batch_hash(files) == batch_hash(r["files"]) || error("corrupt final batch result")
            return result
        end
        parent = batch_safe_path(joinpath(work, "merges"); root = work); mkpath(parent)
        stage = mktempdir(parent; prefix = "merge-", cleanup = false)
        samples = [sample_by_name(cfg, n) for n in m["samples"]]
        for s in samples
            batch_atomic_json(skim_path(stage, s.name), m["skims"][s.name])
        end
        # Exact manifest inventory, never arbitrary filesystem glob ingestion.
        for task in m["tasks"]
            batch_lock(joinpath(work, "locks", task["id"] * ".lock")) do
                verified = batch_receipt(work, m, cfg, task)
                verified === nothing && error("task receipt vanished")
                for (rel, hash) in verified.receipt["files"]
                    first(splitpath(rel)) in ("select", "correct", "histogram") || continue
                    dest = joinpath(stage, rel); mkpath(dirname(dest))
                    ispath(dest) && error("duplicate task artifact: $rel")
                    cp(joinpath(verified.dir, rel), dest)
                    bytes2hex(open(sha256, dest)) == hash || error("task changed during staging")
                end
            end
        end
        opts = RunOptions(m["config"]; profile = m["profile"], workdir = stage, max_files = Int(m["max_files"]), force = true)
        for step in steps
            run_step(step, StepContext(cfg, stage, step, samples, opts))
        end
        batch_rebase_outputs(stage, result)
        batch_load(work)
        batch_status(work)["complete"] || error("task inventory changed before final publication")
        batch_atomic_json(joinpath(stage, "batch-result.json"), Dict("manifest" => m["id"],
            "steps" => String.(steps), "files" => batch_files(stage)))
        Base.Filesystem.rename(stage, result)
        return result
    end
end
