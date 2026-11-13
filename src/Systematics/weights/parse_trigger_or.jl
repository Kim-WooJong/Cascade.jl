"Parse the explicitly scoped independent-single-path trigger OR terms."
function parse_trigger_or(raw, sets, objects, exprvars, errs)
    raw isa AbstractVector || (push!(errs, "corrections.trigger_or must be an array of tables"); return TriggerOR[])
    terms = TriggerOR[]
    for (i, t) in enumerate(raw)
        w = "corrections.trigger_or[$i]"
        _unknown_keys!(errs, w, t, ("name", "path", "topology", "object", "indices", "when", "data", "mc"))
        t isa AbstractDict || continue
        name = _name!(errs, w, t, exprvars)
        path = _string!(errs, w, t, "path")
        get(t, "topology", "") == "independent_single_path_or" || push!(errs,
            "$w: topology must be 'independent_single_path_or'; correlated paths and multi-leg triggers are unsupported")
        obj = _string!(errs, w, t, "object")
        isempty(obj) || obj in objects || push!(errs, "$w: unknown object '$obj'")
        idx = get(t, "indices", nothing)
        indices = Int[]
        if idx isa AbstractVector && !isempty(idx) && all(x -> x isa Integer && !(x isa Bool) && x >= 1, idx)
            indices = Int.(idx)
            allunique(indices) || push!(errs, "$w: indices must be unique (an object cannot be an independent trial twice)")
        else
            push!(errs, "$w: indices must be a non-empty list of positive integers")
        end
        when = get(t, "when", "")
        if !(when isa AbstractString)
            push!(errs, "$w: when must be a string"); when = ""
        elseif !isempty(when)
            try
                parse_expression(when)
            catch e
                push!(errs, "$w: when: $(sprint(showerror, e))")
            end
        end
        efficiencies = TriggerEfficiency[]
        for kind in ("data", "mc")
            b = get(t, kind, nothing)
            _unknown_keys!(errs, "$w.$kind", b, ("set", "correction", "inputs", "systematic", "nominal", "up", "down"))
            b isa AbstractDict || (b = Dict{String,Any}())
            # Reuse the correction binding contract without exposing an inner nuisance name.
            common = Dict{String,Any}(String(k) => v for (k, v) in b)
            common["name"] = name
            for key in ("systematic", "nominal", "up", "down")
                if haskey(common, key) && !(common[key] isa AbstractString)
                    push!(errs, "$w.$kind: $key must be a string")
                    delete!(common, key)
                end
            end
            _, set, corr, inputs, syst, keys = _common!(errs, "$w.$kind", common, sets, exprvars)
            push!(efficiencies, TriggerEfficiency(set, corr, inputs, syst, keys))
        end
        push!(terms, TriggerOR(name, path, obj, indices, String(when), efficiencies...))
    end
    return terms
end
