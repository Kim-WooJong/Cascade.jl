"""Generate a reusable resolved TOML with explicit reduced reader mappings."""
function reduced_analysis_config(cfg, samples, records, final)
    raw = deepcopy(cfg.raw)
    resolve(p) = (q = substitute_paths(String(p), get(raw, "paths", Dict())); isabspath(q) ? q : normpath(joinpath(cfg.dir, q)))
    paths = get(raw, "paths", Dict())
    for (k, v) in paths
        v isa AbstractString && (paths[k] = resolve(v))
    end
    for (_, sets) in (("corrections", get(get(raw, "corrections", Dict()), "sets", Dict())),)
        for (k, p) in sets
            sets[k] = resolve(p)
        end
    end
    for shape in get(raw, "shape_variations", Any[]), k in ("corrections", "resolution", "scale_factor", "smear_file")
        haskey(shape, k) && k in ("corrections", "smear_file") && (shape[k] = resolve(shape[k]))
    end
    if haskey(raw, "data_quality") && !isempty(get(raw["data_quality"], "golden_json", ""))
        raw["data_quality"]["golden_json"] = cfg.data_quality.golden_json
    end
    haskey(raw, "luminosity") && haskey(raw["luminosity"], "file") && (raw["luminosity"]["file"] = resolve(raw["luminosity"]["file"]))
    raw["samples"] = Any[]
    for s in samples
        d = deepcopy(s.raw)
        d["format"] = all(haskey(r, "group_id") for r in records) ? "reduced_rntuple_group" : "reduced_rntuple"; d["source"] = Dict{String,Any}()
        d["files"] = [joinpath(final, r["path"]) for r in records if r["sample"] == s.name]
        pop!(d, "audit", nothing) # Original-population declarations remain in derivation provenance.
        push!(raw["samples"], d)
    end
    get!(raw, "analysis", Dict{String,Any}())["workdir"] = joinpath(final, "analysis_output")
    return raw
end
