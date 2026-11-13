"""
    audit_inputs(cfg::AnalysisConfig; samples=String[]) -> Dict

Freshly audit all discovered files of selected samples, without selection,
normalization changes, cached skim reuse, or Events-column reads for NanoAOD.
All configured inventories are consulted for shared physical files. A pass
means no operational errors found, not certified dataset/physics completeness.
"""
function audit_inputs(cfg::AnalysisConfig; samples::Vector{String} = String[])
    selected = isempty(samples) ? [s.name for s in cfg.samples] : unique(samples)
    for name in selected; sample_by_name(cfg, name); end
    findings = Any[]
    inventories = Dict{String,Any}()
    for s in cfg.samples
        local_findings = Any[]
        inventories[s.name] = audit_inventory(s, local_findings)
        s.name in selected && append!(findings, local_findings)
    end
    audit_identity!(inventories, selected, findings)
    info = Dict{String,Any}()
    for s in cfg.samples
        s.name in selected || continue
        info[s.name] = audit_sample(s, inventories[s.name], cfg, findings)
    end
    signatures = [(name, [(f["signature"], f["identity"]) for f in info[name]["files"]]) for name in selected]
    dq = cfg.data_quality
    q = get(cfg.raw, "luminosity", Dict())
    exposure = Dict{String,Any}("status" => "unknown", "lumi_configured_pb" => isfinite(cfg.lumi_pb) ? cfg.lumi_pb : nothing,
        "mode" => get(q, "mode", "configured"), "assume_complete_lumisections" => get(q, "assume_complete_lumisections", false),
        "run_range" => [dq.run_min, dq.run_max], "run_branch" => dq.run_branch, "lumi_branch" => dq.lumi_branch,
        "golden_json" => dq.golden_json, "golden_sha256" => isempty(dq.golden_json) ? nothing : bytes2hex(sha256(read(dq.golden_json))),
        "scope" => "metadata only; no event run/LS scan, no measured exposure, no proof of complete LS/stream coverage")
    counts = Dict(severity => count(f -> f["severity"] == severity, findings) for severity in ("error", "warning", "unknown"))
    return Dict{String,Any}("schema_version" => 1, "analysis" => cfg.name, "status" => counts["error"] == 0 ? "pass" : "fail",
        "status_scope" => "input operational checks only, not physics readiness or authoritative inventory completeness",
        "created_unix" => time(), "scope" => Dict("metadata_samples" => selected,
        "identity_inventory_samples" => [s.name for s in cfg.samples], "file_limit" => nothing),
        "order" => selected, "samples" => info, "findings" => findings, "finding_counts" => counts,
        "exposure" => exposure, "event_id_duplicates" => "not_assessed", "copied_content_duplicates" => "not_assessed",
        "provenance" => Dict{String,Any}("config_path" => cfg.path, "config_hash" => canonical_hash(cfg.raw),
            "input_signature_hash" => canonical_hash(signatures), "julia_version" => string(VERSION),
            "input_signature_policy" => "path/size/mtime plus physical identity; no input content checksum", "cache" => "none"))
end
