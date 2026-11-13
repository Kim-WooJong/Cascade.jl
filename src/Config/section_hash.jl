"""
    section_hash(cfg::AnalysisConfig, sections...; extra = nothing) -> String

Stable hash of the named top-level TOML sections of `cfg` (missing sections hash
as `null`) plus an optional `extra` value. Used by the pipeline to decide
whether a step must be rerun after a configuration change.
"""
function section_hash(cfg::AnalysisConfig, sections::AbstractString...; extra = nothing)
    d = Dict{String,Any}(String(s) => get(cfg.raw, String(s), nothing) for s in sections)
    extra === nothing || (d["__extra__"] = extra)
    return canonical_hash(d)
end
