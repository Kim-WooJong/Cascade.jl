"""Execution-only same-file range pool. Disabled unless explicitly requested.

Uses the existing stream_* budgets; no new scientific/hash parameter.
Public integration: include this file after AnalysisConfig.jl and export
 event_range_selection. Validate this helper for raw and every merged profile.
"""
function event_range_selection(raw::AbstractDict)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "event_range_selection", false)
    enabled isa Bool || throw(ArgumentError("execution.event_range_selection must be boolean"))
    return enabled
end
event_range_selection(cfg::AnalysisConfig) = event_range_selection(cfg.raw)
