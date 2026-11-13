"""Semantic contract for reusing a shape-safe retained raw population.

Histogram edges, fit channels and theory reduction-only CL settings may change;
selection/output expressions, extraction inputs and shape payloads may not.
"""
function reduced_contract(cfg, sample)
    keys = ("objects", "variables", "cuts", "regions", "weights", "triggers", "data_quality", "output", "corrections", "hooks")
    body = Dict{String,Any}(k => deepcopy(get(cfg.raw, k, nothing)) for k in keys)
    body["histograms"] = [Dict(k => get(h, k, nothing) for k in ("name", "values", "when", "regions")) for h in get(cfg.raw, "histograms", Any[])]
    if body["corrections"] isa AbstractDict
        pop!(body["corrections"], "sets", nothing)
    end
    body["data_quality"] = Dict("run_min" => cfg.data_quality.run_min, "run_max" => cfg.data_quality.run_max,
        "run_branch" => cfg.data_quality.run_branch, "lumi_branch" => cfg.data_quality.lumi_branch)
    body["sample"] = Dict("name" => sample.name, "kind" => String(sample.kind), "stream" => sample.stream)
    body["shape"] = shape_key(shape_variations(cfg))
    body["correction_files"] = correction_files_key(cfg)
    body["golden"] = isempty(cfg.data_quality.golden_json) ? "" : bytes2hex(sha256(read(cfg.data_quality.golden_json)))
    extraction = theory_extraction(cfg; samples = [sample])
    body["theory_terms"] = isempty(extraction) ? Any[] : extraction[sample.name]["contract"]["terms"]
    body["selection_code"] = code_hash(["Selection", "Objects", "Systematics/shape", "Corrections"])
    return canonical_hash(body)
end
