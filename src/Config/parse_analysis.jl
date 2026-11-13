"""
    parse_analysis(d::AbstractDict; path = "", dir = pwd()) -> AnalysisConfig

Build an `AnalysisConfig` from an already-parsed TOML dictionary. Relative file
paths (sample patterns, Golden JSON) are resolved against `dir`.
See `analyses/ttbar_emu/analysis.toml` for the reference layout.
"""
function parse_analysis(d::AbstractDict; path::AbstractString = "", dir::AbstractString = pwd(), profile::AbstractString = "")
    raw = resolve_config(d; profile, check_keys = false)
    paths = Dict{String,Any}(get(raw, "paths", Dict{String,Any}()))
    resolve(p) = (resolved_path = substitute_paths(p, paths); isabspath(resolved_path) ? resolved_path : normpath(joinpath(dir, resolved_path)))

    a = get(raw, "analysis", Dict{String,Any}())
    name = String(get(a, "name", "analysis"))
    lumi = Float64(get(a, "lumi_pb", NaN))
    workdir = String(get(a, "workdir", joinpath("cascade_out", name)))

    samples = SampleConfig[]
    for s in get(raw, "samples", Any[])
        kind = Symbol(get(s, "kind", "mc"))
        push!(samples, SampleConfig(String(s["name"]), kind,
            [resolve(String(p)) for p in s["files"]],
            String(get(s, "format", "nanoaod")),
            Float64(get(s, "xsec_pb", NaN)), Float64(get(s, "branching_ratio", 1.0)),
            String(get(s, "stream", "")), String(get(s, "group", s["name"])),
            Dict{String,Any}(s)))
    end

    objects = ObjectConfig[]
    for o in get(raw, "objects", Any[])
        clean = get(o, "clean", Dict{String,Any}())
        push!(objects, ObjectConfig(String(o["name"]), String(o["collection"]),
            String(get(o, "cut", "true")),
            String.(get(clean, "against", String[])), Float64(get(clean, "dr", 0.4)),
            String(get(o, "sort_by", ""))))
    end

    variables = Dict{String,String}(String(k) => String(v) for (k, v) in get(raw, "variables", Dict()))
    cuts = [CutConfig(String(c["name"]), String(c["expr"]), Symbol(get(c, "only", "all")))
            for c in get(raw, "cuts", Any[])]
    regions = [RegionConfig(String(r["name"]), String(r["after"]), String(get(r, "expr", "true")))
               for r in get(raw, "regions", Any[])]
    if isempty(regions)
        push!(regions, RegionConfig("signal", isempty(cuts) ? "all" : last(cuts).name))
    end
    hists = [HistogramConfig(String(h["name"]), parse_binning(h), String.(h["values"]),
                             String(get(h, "when", "true")), String.(get(h, "regions", String[])),
                             String(get(h, "xlabel", h["name"])))
             for h in get(raw, "histograms", Any[])]

    w = get(raw, "weights", Dict{String,Any}())
    weights_mc = String.(get(w, "mc", String[]))
    weights_data = String.(get(w, "data", String[]))
    variations = [VariationConfig(String(v["name"]), String(v["up"]), String(v["down"]))
                  for v in get(w, "variations", Any[])]

    t = get(raw, "triggers", nothing)
    triggers = t === nothing ? TriggerConfig() : TriggerConfig(
        Dict{String,Vector{String}}(String(k) => String.(v) for (k, v) in get(t, "groups", Dict())),
        String.(get(t, "priority", String[])),
        Dict{String,Vector{String}}(String(k) => String.(v) for (k, v) in get(t, "streams", Dict())),
        String.(get(t, "mc", String[])))

    q = get(raw, "data_quality", nothing)
    dq = if q === nothing
        DataQualityConfig()
    else
        rr = get(q, "run_range", nothing)
        gj = String(get(q, "golden_json", ""))
        DataQualityConfig(rr === nothing ? typemin(Int) : Int(rr[1]),
                          rr === nothing ? typemax(Int) : Int(rr[2]),
                          isempty(gj) ? "" : resolve(gj),
                          String(get(q, "run_branch", "run")),
                          String(get(q, "lumi_branch", "luminosityBlock")))
    end
    outcols = String.(get(get(raw, "output", Dict()), "columns", String[]))

    return AnalysisConfig(name, String(path), String(dir), lumi, samples, objects, variables,
                          cuts, regions, hists, weights_mc, weights_data, variations,
                          triggers, dq, outcols, workdir, raw)
end
