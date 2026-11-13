"""Execution-only per-file checkpoint-preserving handoff; disabled by default."""
function memory_handoff(raw::AbstractDict)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "memory_handoff", false)
    enabled isa Bool || throw(ArgumentError("execution.memory_handoff must be boolean"))
    return enabled
end
memory_handoff(cfg::AnalysisConfig) = memory_handoff(cfg.raw)
