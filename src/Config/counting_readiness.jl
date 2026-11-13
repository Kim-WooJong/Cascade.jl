"""
    counting_readiness(cfg) -> Dict

Report missing evidence for an opt-in counting measurement, without opening event
inputs or accepting Boolean/unity attestations. Evidence records are TOML files
bound to the resolved scientific configuration and pinned supporting files.
This is a provenance gate, not automatic approval of physics closure.
"""
function counting_readiness(cfg::AnalysisConfig)
    c = get(cfg.raw, "counting", nothing)
    c === nothing && return Dict("status" => "not_requested", "blockers" => String[])
    blockers = String[]
    required = ("trigger_or", "luminosity", "calibration", "backgrounds", "signal_normalization", "theory_acceptance")
    signals = get(c, "signal_samples", String[])
    backgrounds = get(c, "background_samples", String[])
    isempty(signals) && push!(blockers, "signal_samples: empty")
    length(unique(vcat(signals, backgrounds))) == length(signals) + length(backgrounds) || push!(blockers, "sample roles overlap or repeat")
    Set(vcat(signals, backgrounds)) == Set(s.name for s in cfg.samples if is_mc(s)) || push!(blockers, "sample roles must partition all MC samples")
    any(r -> r.name == get(c, "region", ""), cfg.regions) || push!(blockers, "unknown counting region")
    get(c, "lumi_mode", "") == "external" || push!(blockers, "only external luminosity propagation is supported")
    get(c, "br_convention", "") == "included_once_in_scaled_signal" || push!(blockers, "BR must already be included once in scaled signal")
    isempty(strip(get(c, "signal_definition", ""))) && push!(blockers, "signal decay definition missing")
    sigma = get(c, "sigma_ref_pb", NaN)
    sigma isa Real && !(sigma isa Bool) && isfinite(sigma) && sigma > 0 || push!(blockers, "invalid reference cross section")
    for t in get(get(cfg.raw, "corrections", Dict()), "flat", Any[])
        occursin("trigger", lowercase(get(t, "name", ""))) && push!(blockers, "flat trigger placeholder is forbidden")
    end
    for t in get(get(cfg.raw, "fit", Dict()), "normsys", Any[])
        occursin("lumi", lowercase(get(t, "name", ""))) && push!(blockers, "external luminosity cannot also be an in-fit nuisance")
    end
    # Evidence paths cannot bind themselves; everything else scientific is hashed.
    contract = deepcopy(cfg.raw)
    delete!(contract["counting"], "required_evidence")
    binding = canonical_hash(contract)
    evidence = get(c, "required_evidence", Dict())
    for key in required
        path = get(evidence, key, "")
        if !(path isa AbstractString) || isempty(path)
            push!(blockers, "$key: evidence record missing")
            continue
        end
        path = isabspath(path) ? path : normpath(joinpath(cfg.dir, path))
        if !isfile(path)
            push!(blockers, "$key: evidence record not found: $path")
            continue
        end
        try
            record = TOML.parsefile(path)
            get(record, "status", "") == "validated" || error("not validated")
            get(record, "configuration_sha256", "") == binding || error("configuration binding mismatch")
            get(record, "kind", "") == key || error("wrong evidence kind")
            isempty(strip(get(record, "method", ""))) && error("method missing")
            files = get(record, "files", Any[])
            isempty(files) && error("supporting files missing")
            for f in files
                p = f["path"]
                p = isabspath(p) ? p : normpath(joinpath(dirname(path), p))
                isfile(p) && bytes2hex(sha256(read(p))) == f["sha256"] || error("supporting file missing or changed")
            end
        catch err
            push!(blockers, "$key: invalid evidence ($(sprint(showerror, err)))")
        end
    end
    return Dict("status" => isempty(blockers) ? "ready" : "blocked", "blockers" => blockers,
                "configuration_sha256" => binding, "required_evidence" => collect(required))
end

"""Reject unresolved opt-in counting before input discovery, output creation or analysis."""
function require_counting_ready(cfg::AnalysisConfig)
    report = counting_readiness(cfg)
    report["status"] == "blocked" && throw(ArgumentError("counting blocked:\n  " * join(report["blockers"], "\n  ")))
    return report
end
