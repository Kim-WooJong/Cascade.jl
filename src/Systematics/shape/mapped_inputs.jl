"""Map semantic JES/JER input names to payload input names (positional order preserved)."""
function mapped_inputs(cfg::ShapeVariationConfig, names)
    mapping = get(cfg.params, "inputs", Dict())
    return [String(get(mapping, n, n)) for n in names]
end
