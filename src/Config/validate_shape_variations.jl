"""
    validate_shape_variations(cfg::AnalysisConfig) -> Vector{String}

Problems of the `[[shape_variations]]` tables (empty if valid): parse errors,
duplicate or invalid names, labels clashing with weight variations, unknown or
non-MC samples, missing correction files or settings, more than one nominal
JER smearing per collection.
"""
function validate_shape_variations(cfg::AnalysisConfig)
    errs = String[]
    vs = try
        shape_variations(cfg)
    catch e
        e isa ArgumentError || rethrow()
        return [e.msg]
    end
    names = [v.name for v in vs]
    wlabels = Set(w.name for w in cfg.variations)
    samples = Dict(s.name => s for s in cfg.samples)
    nominal_jer = Dict{String,Int}()
    for v in vs
        what = "shape variation $(v.name)"
        occursin(r"^[A-Za-z0-9_]+$", v.name) || push!(errs, "$what: name must match [A-Za-z0-9_]+")
        count(==(v.name), names) > 1 && push!(errs, "duplicate shape variation name '$(v.name)'")
        v.name in wlabels && push!(errs, "$what: name also used by a weight variation")
        occursin(r"^[A-Za-z0-9]+$", v.collection) || push!(errs, "$what: collection must be a NanoAOD prefix")
        isempty(v.fields) && push!(errs, "$what: no fields")
        for s in v.samples
            haskey(samples, s) || (push!(errs, "$what: unknown sample '$s'"); continue)
            is_mc(samples[s]) || push!(errs, "$what: sample '$s' is not MC")
        end
        v.met_min_pt >= 0 || push!(errs, "$what: met_min_pt must be >= 0")
        p = v.params
        need(keys...) = for k in keys
            (p[k] isa AbstractString && isempty(p[k])) && push!(errs, "$what: '$k' is required")
        end
        if v.kind === :jes
            need("corrections", "source")
        elseif v.kind === :jer
            need("corrections", "resolution", "scale_factor", "smear_file", "smear", "rho", "event",
                 "genjet", "genjet_index")
            "pt" in v.fields || push!(errs, "$what: fields must include pt")
            p["nominal"] isa Bool || push!(errs, "$what: nominal must be true or false")
            p["nominal"] === true && (nominal_jer[v.collection] = get(nominal_jer, v.collection, 0) + 1)
        else
            need("up", "down")
        end
        for k in SHAPE_PATH_PARAMS
            f = get(p, k, "")
            f isa AbstractString && !isempty(f) && !isfile(f) && push!(errs, "$what: $k not found: $f")
        end
    end
    for (c, k) in nominal_jer
        k > 1 && push!(errs, "collection $c: more than one jer variation with nominal = true")
    end
    return errs
end
