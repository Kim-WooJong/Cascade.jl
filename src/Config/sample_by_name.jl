"""
    sample_by_name(cfg::AnalysisConfig, name) -> SampleConfig

Look up a sample; throws `KeyError` if it is not defined.
"""
function sample_by_name(cfg::AnalysisConfig, name::AbstractString)
    i = findfirst(s -> s.name == name, cfg.samples)
    i === nothing && throw(KeyError(name))
    return cfg.samples[i]
end
