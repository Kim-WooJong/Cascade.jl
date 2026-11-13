"""Validate output-bearing path components at the batch boundary, not serial parsing."""
function batch_validate_names(cfg)
    names = Pair{String,String}[]
    append!(names, ["sample" => s.name for s in cfg.samples])
    append!(names, ["region" => r.name for r in cfg.regions])
    append!(names, ["histogram" => h.name for h in cfg.histograms])
    append!(names, ["shape variation" => s.name for s in shape_variations(cfg)])
    for c in get(get(cfg.raw, "fit", Dict()), "channels", Any[])
        r, v = String(c["region"]), String(c["variable"])
        append!(names, ["fit region" => r, "fit variable" => v,
            "fit channel" => String(get(c, "name", r * "_" * v))])
    end
    for key in ("regions", "variables", "logy"), n in get(get(cfg.raw, "plot", Dict()), key, String[])
        push!(names, "plot $key" => String(n))
    end
    for (kind, name) in names
        !isempty(name) && name ∉ (".", "..") &&
            all(c -> isletter(c) || isdigit(c) || c in ('_', '-', '.'), name) ||
            throw(ArgumentError("unsafe batch $kind path component: $name"))
    end
    return nothing
end
