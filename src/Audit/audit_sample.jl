"Inspect one complete discovered sample inventory without modifying normalization."
function audit_sample(s::SampleConfig, inventory, cfg::AnalysisConfig, findings)
    population_valid = true
    try
        validate_source_populations(s.format, [f["path"] for f in inventory["files"] if f["exists"]]; options = get(s.raw, "source", Dict()))
    catch e
        population_valid = false
        audit_finding!(findings, "error", "normalization_population_invalid", sprint(showerror, e); sample = s.name)
    end
    files = [audit_file(s, record, findings) for record in inventory["files"]]
    complete = all(f -> f["read_status"] == "ok", files) && !isempty(files)
    readable = [f for f in files if f["read_status"] == "ok"]
    events = sum((f["nevents"] for f in readable); init = 0)
    norm_complete = population_valid && complete && all(f -> f["normalization"]["status"] == "available", files)
    sumw = 0.0
    for f in files # Same sorted per-file addition order as production merge.
        f["normalization"]["status"] == "available" && (sumw += f["normalization"]["value"])
    end
    if is_mc(s) && !isfinite(sumw)
        norm_complete = false
        audit_finding!(findings, "error", "nonfinite_sample_sumw", "aggregate generator sum is not finite"; sample = s.name)
    elseif is_mc(s) && norm_complete && sumw == 0
        audit_finding!(findings, "error", "zero_sample_sumw", "zero aggregate generator sum cannot normalize MC"; sample = s.name)
    end
    if is_mc(s)
        for key in ("xsec_pb", "branching_ratio")
            get(s.raw, key, 1.0) isa Bool && audit_finding!(findings, "error", "invalid_normalization_type", "$key must be numeric, not boolean"; sample = s.name)
        end
        isfinite(s.xsec_pb) && s.xsec_pb > 0 || audit_finding!(findings, "error", "invalid_xsec", "MC cross section must be finite and positive"; sample = s.name)
        isfinite(s.branching_ratio) && 0 <= s.branching_ratio <= 1 || audit_finding!(findings, "error", "invalid_branching_ratio", "branching ratio must be finite and within [0,1]"; sample = s.name)
    end
    metadata = get(s.raw, "metadata", Dict{String,Any}())
    declarations = Dict(key => haskey(s.raw, key) ? "declared" : "defaulted" for key in ("kind", "format", "branching_ratio", "group", "stream"))
    declarations["xsec_pb"] = haskey(s.raw, "xsec_pb") ? "declared" : "unspecified"
    for key in ("dataset", "era", "campaign", "xsec_source")
        if !haskey(metadata, key) && (key != "xsec_source" || is_mc(s))
            audit_finding!(findings, "unknown", "metadata_unspecified", "sample metadata '$key' is not declared; no value inferred from its name"; sample = s.name)
        end
    end
    result = Dict{String,Any}("name" => s.name, "kind" => String(s.kind), "format" => s.format,
        "group" => s.group, "stream" => s.stream, "metadata" => metadata, "declarations" => declarations,
        "xsec_pb" => isfinite(s.xsec_pb) ? s.xsec_pb : nothing,
        "branching_ratio" => isfinite(s.branching_ratio) ? s.branching_ratio : nothing,
        "source_options" => get(s.raw, "source", Dict()), "patterns" => inventory["patterns"], "files" => files,
        "discovered_nfiles" => length(files),
        "physical_nfiles" => sum(get(f, "physical_nfiles", 0) for f in readable; init = 0), "attempted_nfiles" => count(f -> f["exists"], files),
        "readable_nfiles" => length(readable), "source_metadata_complete" => complete,
        "nevents" => complete ? events : nothing, "partial_nevents" => events,
        "gen_weight_sum" => is_mc(s) && norm_complete ? sumw : nothing,
        "partial_gen_weight_sum" => is_mc(s) && isfinite(sumw) ? sumw : nothing,
        "normalization_status" => is_data(s) ? "not_applicable" : norm_complete && sumw != 0 ? "available" : "unavailable",
        "inventory_completeness" => "unknown", "checks" => Any[])
    audit_expectations!(result, s, cfg, findings)
    return result
end
