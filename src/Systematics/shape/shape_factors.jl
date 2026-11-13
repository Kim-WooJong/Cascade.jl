"""
    shape_factors(v::ShapeVariation, cols, needed) -> NamedTuple

Per-object factors of one variation: `(nominal, up, down, from_raw)`.
`nominal` is `nothing` unless the variation also changes the nominal (JER with
`nominal = true`). `from_raw = true`: `up`/`down` apply to the unvaried input
values (JER), otherwise to the nominal values (JES, scale).
"""
function shape_factors(v::ShapeVariation{JESShape}, cols::AbstractDict, needed)
    up, down = jes_factors(v.kind, v.config.collection, cols, needed)
    return (nominal = nothing, up = up, down = down, from_raw = false)
end

function shape_factors(v::ShapeVariation{JERShape}, cols::AbstractDict, needed)
    nom, up, down = jer_factors(v.kind, v.config.collection, cols, needed)
    return (nominal = v.kind.nominal ? nom : nothing, up = up, down = down, from_raw = true)
end

function shape_factors(v::ShapeVariation{ScaleShape}, cols::AbstractDict, needed)
    up, down = scale_factors(v.kind, cols, needed)
    return (nominal = nothing, up = up, down = down, from_raw = false)
end
