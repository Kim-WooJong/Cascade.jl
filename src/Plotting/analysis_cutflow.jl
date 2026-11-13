"""
    analysis_cutflow(cfg::AnalysisConfig, samples_info::AbstractDict, config::StackConfig) -> Cutflow

Grouped cutflow (stack groups of `config` plus a `"Data"` column) from the
`samples` table of `merge/samples.json` (per sample `cutflow` with raw
`names`, `sumw`, `sumw2` and the normalisation `norm`). Stages are `"all"` and
every cut of the analysis in order; a cut that does not apply to a sample kind
(e.g. `only = "data"`) keeps that sample's previous stage value. Simulated
columns are scaled by `norm` (see [`group_cutflow`](@ref)).
"""
function analysis_cutflow(cfg::AnalysisConfig, samples_info::AbstractDict, config::StackConfig)
    stages = ["all"; [c.name for c in cfg.cuts]]
    sumw = Dict{String,Vector{Float64}}(); sumw2 = Dict{String,Vector{Float64}}()
    scale = Dict{String,Float64}()
    for (name, info) in samples_info
        cf = info["cutflow"]
        idx = Dict(String(n) => i for (i, n) in enumerate(cf["names"]))
        w = zeros(length(stages)); v = zeros(length(stages))
        k = 1
        for (j, s) in enumerate(stages)
            haskey(idx, s) && (k = idx[s])
            w[j] = Float64(cf["sumw"][k]); v[j] = Float64(cf["sumw2"][k])
        end
        sumw[String(name)] = w; sumw2[String(name)] = v
        scale[String(name)] = Float64(info["norm"])
    end
    cols = sort(collect(keys(sumw)))
    cf = Cutflow(stages, sumw; sumw2, columns = cols, data = [d for d in config.data if d in cols])
    stack = present_stack(config, cols)
    stack === nothing && throw(ArgumentError("no stacked sample has a cutflow"))
    return group_cutflow(cf, stack; scale, allow_missing = true)
end
