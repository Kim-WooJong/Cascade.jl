"""
    shape_plan(configs::AbstractVector{ShapeVariationConfig}, used) -> ShapePlan

Load and compile the shape variations `configs` for a selection reading the
columns `used` (e.g. `vcat(sel.columns_pre, sel.columns_post)`). Call it outside
threaded code (expressions are compiled with `eval`).
"""
function shape_plan(configs::AbstractVector{ShapeVariationConfig}, used)
    u = Set{String}(String.(collect(used)))
    vs = ShapeVariation[ShapeVariation(c) for c in configs]
    inputs = unique!(reduce(vcat, (shape_inputs(v, u) for v in vs); init = String[]))
    replaces = String[]
    for v in vs
        c = v.config
        append!(replaces, [string(c.collection, "_", f) for f in c.fields])
        isempty(c.met) || append!(replaces, [c.met * "_pt", c.met * "_phi"])
    end
    labels = reduce(vcat, ([c.config.name * "Up", c.config.name * "Down"] for c in vs); init = String[])
    return ShapePlan(vs, u, inputs, unique!(replaces), labels)
end
