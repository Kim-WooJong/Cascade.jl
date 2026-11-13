"""
    group_templates(templates, config::StackConfig; allow_missing=false) -> Vector{SampleTemplates}

Sum the per-sample templates into the stack groups of `config` (bottom to top;
each result is named by the group label) with [`merge_samples`](@ref). Missing
samples are errors unless `allow_missing=true`.
"""
group_templates(templates::AbstractDict{<:AbstractString,SampleTemplates}, config::StackConfig;
                allow_missing::Bool=false) =
    [merge_samples(templates, g.samples; name=g.label, allow_missing) for g in config.groups]
