"""
    load_ttbar_templates(mcdir, datadir, cfg; variables=nothing) -> Dict{String,Dict{String,SampleTemplates}}

Per variable, the templates of every simulated sample (normalised with
[`ttbar_scale_factors`](@ref)) and every data sample. Illustrative normalisation
variations `<name>Up/Down = (1 ± size) × nominal` from `cfg["illustrative_norm"]`
are attached to the listed samples. Built through the plain-array contract
`(sample, variation) => (edges, sumw, sumw2)` of `collect_templates`.
"""
function load_ttbar_templates(mcdir::AbstractString, datadir::AbstractString, cfg::AbstractDict;
                              variables=nothing)
    scale = ttbar_scale_factors(mcdir, cfg)
    vars = variables === nothing ? [v["name"] for v in cfg["variables"]] : collect(variables)
    entries = Dict(v => Dict{Tuple{String,String},Any}() for v in vars)
    for (sample, c) in scale
        _, hists = read_ttbar_tsv(joinpath(mcdir, sample * ".tsv"))
        for v in vars
            h = hist_scale(hists[v], c)
            entries[v][(sample, "nominal")] = (h.edges, h.sumw, h.sumw2)
            for n in get(cfg, "illustrative_norm", [])
                sample in n["samples"] || continue
                k = Float64(n["size"])
                entries[v][(sample, n["name"] * "Up")] = hist_scale(h, 1 + k)
                entries[v][(sample, n["name"] * "Down")] = hist_scale(h, 1 - k)
            end
        end
    end
    for pd in cfg["plotting"]["data"]
        _, hists = read_ttbar_tsv(joinpath(datadir, pd * ".tsv"))
        for v in vars
            entries[v][(pd, "nominal")] = hists[v]
        end
    end
    return Dict(v => collect_templates(e) for (v, e) in entries)
end
