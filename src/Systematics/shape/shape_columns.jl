"""
    shape_columns(plan::ShapePlan, raw::AbstractDict, needed) -> Vector{Pair{String,Dict{String,Any}}}

Varied columns of one chunk for `Selection.run_selection_variations`:
`"nominal" =>` replacements if a JER variation smears the nominal (absent
otherwise), then `"<name>Up"`, `"<name>Down"` per variation. Each varied field
(`fields` read by the selection) is `T(Float64(x) * factor)` where `x` is the
nominal value (JES, scale; nominal = JER-smeared if enabled) or the unvaried
input value (JER directions). MET (if configured and read) is recomputed with
`propagate_met` relative to the nominal. Factors are computed once per chunk.
"""
function shape_columns(plan::ShapePlan, raw::AbstractDict, needed)
    facs = [shape_factors(v, raw, needed) for v in plan.variations]
    nominal = Dict{String,Any}()
    for (k, v) in enumerate(plan.variations)
        f = facs[k].nominal
        f === nothing && continue
        _vary!(nominal, plan, v, raw, raw, raw, f, needed)
    end
    out = Pair{String,Dict{String,Any}}[]
    isempty(nominal) || push!(out, "nominal" => nominal)
    base = isempty(nominal) ? raw : merge(raw, nominal)
    for (k, v) in enumerate(plan.variations)
        ref = facs[k].from_raw ? raw : base
        for (label, f) in ((v.config.name * "Up", facs[k].up), (v.config.name * "Down", facs[k].down))
            rep = Dict{String,Any}()
            _vary!(rep, plan, v, raw, ref, base, f, needed)
            push!(out, label => rep)
        end
    end
    return out
end

# Scale the used fields of `ref` by `f` into `rep`; propagate the pt change
# (relative to `base`) to the MET if configured and read by the selection.
function _vary!(rep, plan, v, raw, ref, base, f, needed)
    c = v.config; coll = c.collection
    ptname = coll * "_pt"
    newpt = nothing
    for fld in c.fields
        name = string(coll, "_", fld)
        name in plan.used || continue
        rep[name] = scale_column(ref[name], f, needed)
        fld == "pt" && (newpt = rep[name])
    end
    mp = c.met * "_pt"; mf = c.met * "_phi"
    if !isempty(c.met) && (mp in plan.used || mf in plan.used)
        newpt === nothing && (newpt = scale_column(ref[ptname], f, needed))
        pt, phi = propagate_met(base[mp], base[mf], raw[coll * "_phi"], base[ptname], newpt, raw[ptname],
                                c.met_min_pt, needed)
        mp in plan.used && (rep[mp] = pt)
        mf in plan.used && (rep[mf] = phi)
    end
    return rep
end
