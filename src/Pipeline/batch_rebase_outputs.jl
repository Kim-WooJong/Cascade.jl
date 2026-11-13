"""Rebase only the plot output index from staging to final publication paths.

Scientific input provenance is deliberately untouched. Every indexed output must
already exist inside the staging directory before its final path is persisted.
"""
function batch_rebase_outputs(stage, result)
    index = joinpath(stage, "plot", "index.json")
    isfile(index) || return nothing
    value = _jsdict(JSON3.read(read(index, String)))
    files = String[]
    for path in value["files"]
        source = batch_safe_path(path; root = stage)
        isfile(source) || error("missing indexed batch output: $source")
        push!(files, batch_safe_path(joinpath(result, relpath(source, stage)); root = result))
    end
    value["files"] = files
    batch_atomic_json(index, value)
    return nothing
end
