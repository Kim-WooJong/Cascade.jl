"""Execution-only bounded named-variable caching; disabled by default."""
function memoization_options(raw::AbstractDict)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "memoize_variables", false)
    enabled isa Bool || throw(ArgumentError("execution.memoize_variables must be boolean"))
    limit = get(execution, "memoize_max_bytes", 268435456)
    limit isa Integer && !(limit isa Bool) && 0 < limit <= typemax(Int) ||
        throw(ArgumentError("execution.memoize_max_bytes must be a positive Int-sized integer"))
    return (enabled = enabled, max_bytes = Int(limit))
end
memoization_options(cfg::AnalysisConfig) = memoization_options(cfg.raw)

"""Execution-only opt-in: reproducible typed selection kernels (Selection.compile_stable_kernel);
disabled by default. Never part of scientific identity: kernel bodies are unchanged."""
function stable_selection_kernels(raw::AbstractDict)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "stable_selection_kernels", false)
    enabled isa Bool || throw(ArgumentError("execution.stable_selection_kernels must be boolean"))
    return enabled
end
stable_selection_kernels(cfg::AnalysisConfig) = stable_selection_kernels(cfg.raw)
