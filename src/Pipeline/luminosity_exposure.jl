"Aggregate selected input coverage and explicit luminosity provenance for a run."
function luminosity_exposure(ctx::StepContext, skims, spec = luminosity_spec(ctx.config))
    cfg = ctx.config
    mode = spec["mode"]
    coverage = Set{Tuple{Int,Int}}()
    per_sample = Dict{String,Any}()
    truncated = false
    selected, available = 0, 0
    for s in ctx.samples
        skim = skims[s.name]
        evidence = get(skim, "groups", skim["files"])
        nf = length(evidence)
        na = Int(get(skim, "available_nfiles", nf))
        tr = Bool(get(skim, "truncated", false))
        truncated |= tr
        selected += nf; available += na
        cov = Set{Tuple{Int,Int}}()
        if mode == "certified" && is_data(s)
            get(skim, "exposure_key", nothing) == canonical_hash(spec) ||
                throw(ArgumentError("stale luminosity coverage for $(s.name); rerun skim with the current luminosity/data_quality configuration"))
            for e in evidence
                haskey(e, "certified_observed_lumisections") ||
                    throw(ArgumentError("no run/LS coverage for $(s.name); rerun skim in certified luminosity mode"))
                for p in e["certified_observed_lumisections"]
                    push!(cov, (Int(p[1]), Int(p[2])))
                end
            end
            union!(coverage, cov)
        end
        per_sample[s.name] = Dict("selected_nfiles" => nf, "physical_nfiles" => length(skim["files"]), "available_nfiles" => na,
            "truncated" => tr, "certified_observed_lumisection_count" => mode == "certified" && is_data(s) ? length(cov) : nothing)
    end
    observed_lumi = nothing
    used = cfg.lumi_pb
    if mode == "certified"
        any(is_data, ctx.samples) || throw(ArgumentError("certified luminosity requires selected data samples to establish observed run/LS coverage"))
        isempty(coverage) && throw(ArgumentError("no certified observed data lumisections; cannot derive a positive MC normalization"))
        table = load_lumisection_luminosity(spec["file"])
        observed_lumi = lumisection_luminosity(coverage, table)
        observed_lumi > 0 || throw(ArgumentError("certified observed lumisection luminosity must be positive"))
        used = observed_lumi
    elseif truncated
        @warn "Selected input files are truncated; actual data exposure is unknown. MC normalization retains configured analysis.lumi_pb; no file-count/event-count luminosity correction was applied." max_files=ctx.options.max_files lumi_pb=cfg.lumi_pb
    end
    return merge(copy(spec), Dict{String,Any}("lumi_configured_pb" => cfg.lumi_pb,
        "lumi_used_pb" => used, "observed_lumisection_lumi_pb" => observed_lumi,
        "exposure_status" => mode == "certified" ? "assumed_complete_observed_lumisections" : "unknown",
        "coverage_scope" => mode == "certified" ? "union of certified run/LS pairs observed before physics selection in selected data files; complete LS and stream coverage are user assumptions, not verified by event counts" : "not measured; configured luminosity retained",
        "truncated" => truncated, "max_files" => ctx.options.max_files,
        "selected_nfiles" => selected, "available_nfiles" => available,
        "certified_observed_lumisection_count" => mode == "certified" ? length(coverage) : nothing,
        "certified_observed_lumisections" => mode == "certified" ? [collect(p) for p in sort!(collect(coverage))] : nothing,
        "samples" => per_sample))
end
