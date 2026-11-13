"""
    resolve_config(raw; profile = "") -> Dict

Resolve one deep-merged profile, then option switches and enabled entries.
Tables merge recursively; arrays replace. The input is never mutated.
"""
function resolve_config(raw::AbstractDict; profile::AbstractString = "", check_keys::Bool = true)
    check_keys && validate_keys(raw)
    d = _config_copy(raw)
    options = get(d, "options", Dict{String,Any}())
    chosen = isempty(profile) ? String(get(options, "default_profile", "")) : String(profile)
    profiles = pop!(d, "profiles", Dict{String,Any}())
    if !isempty(chosen)
        haskey(profiles, chosen) || throw(ArgumentError("profiles.$chosen: unknown profile"))
        _profile_merge!(d, profiles[chosen])
        a = get!(d, "analysis", Dict{String,Any}())
        a["workdir"] = joinpath(get(a, "workdir", joinpath("cascade_out", get(a, "name", "analysis"))), chosen)
    end
    options = pop!(d, "options", Dict{String,Any}())
    validate_keys(Dict("options" => options))
    prune_sets = false
    corr = get(d, "corrections", nothing)
    if corr !== nothing
        for k in ("object_sf", "event_weight", "flat", "trigger_or")
            prune_sets |= any(t -> get(t, "enabled", true) === false, get(corr,k,Any[]))
            haskey(corr, k) && (corr[k] = _enabled_entries(corr[k], "corrections.$k"))
        end
        sw = get(options, "corrections", true)
        if sw === false
            delete!(d, "corrections")
            hooks = get(d, "hooks", Dict())
            get(hooks, "correct", "") == "Cascade.Systematics.apply_corrections" && delete!(hooks, "correct")
            isempty(hooks) && delete!(d, "hooks")
        elseif sw isa AbstractVector
            prune_sets = true
            for k in ("object_sf", "event_weight", "flat", "trigger_or")
                haskey(corr,k) && (corr[k] = [t for t in corr[k] if t["name"] in sw])
            end
        elseif sw !== true
            throw(ArgumentError("options.corrections must be boolean or a list of names"))
        end
    end
    if prune_sets && haskey(d, "corrections")
        c = d["corrections"]
        aliases = Set(get(t, "set", "") for k in ("object_sf", "event_weight") for t in get(c,k,Any[]))
        for t in get(c, "trigger_or", Any[]), side in ("data", "mc")
            push!(aliases, get(get(t, side, Dict()), "set", ""))
        end
        haskey(c, "sets") && filter!(kv -> first(kv) in aliases, c["sets"])
    end
    haskey(d, "theory_weights") && (d["theory_weights"] = _enabled_entries(d["theory_weights"], "theory_weights"))
    if haskey(d, "shape_variations")
        shapes = _enabled_entries(d["shape_variations"], "shape_variations")
        sw = get(options, "shape_variations", true)
        sw === false ? (shapes = Any[]) : sw isa AbstractVector ? (shapes = [t for t in shapes if t["name"] in sw]) : sw === true || throw(ArgumentError("options.shape_variations must be boolean or a list of names"))
        for t in shapes
            get(t,"kind", "") == "jer" && haskey(options,"jer_nominal") && (t["nominal"] = options["jer_nominal"])
        end
        d["shape_variations"] = shapes
    end
    if haskey(d,"fit")
        f = d["fit"]
        haskey(f,"normsys") && (f["normsys"] = _enabled_entries(f["normsys"], "fit.normsys"))
        get(options,"fit",true) || delete!(d,"fit")
    end
    return d
end

function _profile_merge!(base, overlay)
    for (k,v) in overlay
        if v isa AbstractDict && get(base,k,nothing) isa AbstractDict
            _profile_merge!(base[k],v)
        else
            base[k] = deepcopy(v)
        end
    end
    return base
end

function _enabled_entries(entries, path)
    out = Any[]
    for (i,t) in enumerate(entries)
        e = get(t,"enabled",true)
        e isa Bool || throw(ArgumentError("$path[$i].enabled must be boolean"))
        e || continue
        t = copy(t); delete!(t,"enabled"); push!(out,t)
    end
    return out
end

_config_copy(d::AbstractDict) = Dict{String,Any}(String(k) => _config_copy(v) for (k,v) in d)
_config_copy(v::AbstractVector) = Any[_config_copy(x) for x in v]
_config_copy(v) = deepcopy(v)
