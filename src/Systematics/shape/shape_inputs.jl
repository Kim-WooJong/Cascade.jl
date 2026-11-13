"""
    shape_inputs(v::ShapeVariation, used) -> Vector{String}

Columns needed to compute the variation: kind inputs (pt, eta, gen jets, rho,
event id, expression columns), the scaled fields read by the selection
(`used`) and, if the selection reads the MET, the MET and object phi.
"""
function shape_inputs(v::ShapeVariation, used)
    c = v.config; coll = c.collection
    out = [coll * "_pt"]
    k = v.kind
    if k isa JESShape
        push!(out, coll * "_eta")
    elseif k isa JERShape
        append!(out, [coll * "_eta", coll * "_phi", string(coll, "_", k.genjet_index), k.genjet * "_pt",
                      k.genjet * "_eta", k.genjet * "_phi", k.rho, k.event])
    elseif k isa ScaleShape
        append!(out, k.up_columns, k.down_columns)
    end
    for f in c.fields
        n = string(coll, "_", f)
        n in used && push!(out, n)
    end
    if !isempty(c.met) && (c.met * "_pt" in used || c.met * "_phi" in used)
        append!(out, [coll * "_phi", c.met * "_pt", c.met * "_phi"])
    end
    return unique!(out)
end
