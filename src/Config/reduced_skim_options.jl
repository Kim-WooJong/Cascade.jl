"""Validate opt-in reduced export settings and conservative eager-writer limits."""
function reduced_skim_options(cfg::AnalysisConfig)
    d = get(cfg.raw, "reduced_skim", Dict())
    get(d, "format", "root_rntuple") == "root_rntuple" || error("reduced_skim.format must be root_rntuple")
    get(d, "retention", "analysis_union") == "analysis_union" || error("only analysis_union retention is supported")
    out = Dict{String,Any}("format" => "root_rntuple", "retention" => "analysis_union")
    for k in ("include", "drop")
        v = get(d, k, String[])
        v isa AbstractVector && all(x -> x isa AbstractString, v) || error("reduced_skim.$k must be a string array")
        out[k] = unique(String.(v))
    end
    mode = get(d, "mode", "streaming")
    mode in ("streaming", "legacy_eager") || error("reduced_skim.mode must be streaming or legacy_eager")
    out["mode"] = mode
    if mode == "streaming"
        any(haskey(d, k) for k in ("max_events", "max_payload_bytes", "max_input_bytes", "max_buffer_bytes")) &&
            error("legacy whole-source reduced limit fields require mode=legacy_eager; use reduced_skim.streaming named window/shard controls")
        return merge(out, streaming_skim_options(d))
    end
    haskey(d, "streaming") && error("streaming options cannot be used in legacy_eager mode")
    for (k, limit) in (("max_events", 1_000_000), ("max_payload_bytes", 64_000_000), ("max_input_bytes", 256_000_000), ("max_buffer_bytes", 1_024_000_000))
        v = get(d, k, limit)
        v isa Integer && !(v isa Bool) && 0 < v <= limit || error("reduced_skim.$k must be in 1:$limit")
        out[k] = Int(v)
    end
    return out
end
