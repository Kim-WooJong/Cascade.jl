"""
    scale_factors(k::ScaleShape, cols, needed) -> (up, down)

Per-object factors of the `up` / `down` expressions (objects of events with
`needed[i] == false`: 1.0).
"""
function scale_factors(k::ScaleShape, cols::AbstractDict, needed)
    up = evaluate_object_expression(k.up, k.up_columns, cols, needed)
    down = evaluate_object_expression(k.down, k.down_columns, cols, needed)
    replace!(x -> isnan(x) ? 1.0 : x, up)
    replace!(x -> isnan(x) ? 1.0 : x, down)
    return up, down
end
