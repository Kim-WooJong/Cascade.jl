"""
    counting_from_store(cfg, store::HistogramStore, sample_summary; nuisances, lumi_relative)

Extract one-event-per-fill counting moments from a normalized merged store and
its samples.json summary. Require matching scientific configuration provenance,
all MC/data samples, nominal yield/cutflow closure and unweighted integer data.
Unbound historical stores are refused, never relabelled as modern results.
The file overload reads existing merge outputs only AFTER readiness succeeds.
"""
function counting_from_store(cfg, store::HistogramStore, summary::AbstractDict; nuisances, lumi_relative)
    report = require_counting_ready(cfg)
    report["status"] == "ready" || throw(ArgumentError("counting configuration required"))
    binding = report["configuration_sha256"]
    get(store.meta, "counting_configuration_sha256", "") == binding || throw(ArgumentError("merged store has missing/foreign counting configuration provenance"))
    get(store.meta, "normalised", false) === true || throw(ArgumentError("counting requires normalized merge output"))
    lumi = get(store.meta, "lumi_pb", nothing)
    lumi isa Real && !(lumi isa Bool) && isfinite(lumi) && lumi > 0 || throw(ArgumentError("merged luminosity missing or invalid"))
    lumi == get(summary,"lumi_pb",nothing) || throw(ArgumentError("store/sample luminosity mismatch"))
    records = summary["samples"]
    Set(keys(records)) == Set(s.name for s in cfg.samples) || throw(ArgumentError("summary sample inventory mismatch"))
    region = cfg.raw["counting"]["region"]
    variable = get(get(cfg.raw, "merge", Dict()), "yield_variable", "")
    matches = filter(h -> h.name == variable, cfg.histograms)
    length(matches) == 1 || throw(ArgumentError("counting yield histogram is not unique"))
    hcfg = only(matches)
    length(hcfg.values) == 1 && hcfg.when == "true" || throw(ArgumentError("counting histogram must fill exactly once per event"))
    rows = NamedTuple{(:name,:sumw,:sumw2),Tuple{String,Float64,Float64}}[]
    observed = 0
    for s in cfg.samples
        key = HistKey(region, s.name, "nominal", variable)
        haskey(store, key) || throw(ArgumentError("missing nominal histogram for $(s.name)"))
        h = store[key]
        h.edges == hcfg.edges || throw(ArgumentError("counting histogram binning mismatch"))
        y, v = sum(h.sumw), sum(h.sumw2)
        rec = records[s.name]["regions"][region]
        isapprox(y, rec["cutflow_yield"]; rtol=1e-10, atol=1e-9) || throw(ArgumentError("counting histogram/cutflow mismatch for $(s.name)"))
        if is_data(s)
            n = rec["selected_event_count"]
            n isa Integer && !(n isa Bool) && n >= 0 || throw(ArgumentError("data cutflow must contain nonnegative integer counts"))
            y == n && v == n || throw(ArgumentError("data histogram is weighted or incomplete"))
            observed = Base.Checked.checked_add(observed, Int(n))
        else
            push!(rows, (name=s.name, sumw=y, sumw2=v))
        end
    end
    return counting_measurement(cfg, rows; observed, nuisances, lumi_relative)
end

function counting_from_store(cfg, histogram_path::AbstractString, samples_path::AbstractString; kwargs...)
    require_counting_ready(cfg) # Must precede even a missing-file read.
    store = read_store(histogram_path)
    summary = JSON3.read(read(samples_path, String), Dict{String,Any})
    return counting_from_store(cfg, store, summary; kwargs...)
end
