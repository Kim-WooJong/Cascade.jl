"""
    batch_status(workdir) -> Dict

Verify the exact receipt inventory. Missing/corrupt work is never success.
Incomplete attempts remain evidence and are safely retried under OS locks.
"""
function batch_status(workdir)
    work = abspath(workdir); m, cfg = batch_load(work)
    expected = Set(t["id"] * ".json" for t in m["tasks"])
    dir = joinpath(work, "receipts")
    extra = isdir(dir) ? sort!(collect(setdiff(Set(readdir(dir)), expected))) : String[]
    states = Dict{String,Any}()
    for task in m["tasks"]
        try
            r = batch_receipt(work, m, cfg, task)
            states[task["id"]] = Dict("status" => r === nothing ? "missing" : "verified")
        catch e
            states[task["id"]] = Dict("status" => "invalid", "error" => sprint(showerror, e))
        end
    end
    complete = isempty(extra) && all(s["status"] == "verified" for s in values(states))
    return Dict("manifest" => m["id"], "complete" => complete, "extra_receipts" => extra, "tasks" => states)
end
