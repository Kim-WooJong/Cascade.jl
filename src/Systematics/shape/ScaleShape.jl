"""
    ScaleShape(cfg::ShapeVariationConfig)

Generic per-object scale variation: `up` / `down` are compiled object
expressions (fields of the collection) giving the multiplicative factors;
`up_columns` / `down_columns` are the columns they read.
"""
struct ScaleShape
    up::Any
    up_columns::Vector{String}
    down::Any
    down_columns::Vector{String}
end

function ScaleShape(cfg::ShapeVariationConfig)
    up, ucols = compile_object_expression(string(cfg.params["up"]), cfg.collection)
    down, dcols = compile_object_expression(string(cfg.params["down"]), cfg.collection)
    # constant expressions read no column: anchor them on the pt column for the object layout
    isempty(ucols) && push!(ucols, cfg.collection * "_pt")
    isempty(dcols) && push!(dcols, cfg.collection * "_pt")
    return ScaleShape(up, ucols, down, dcols)
end
