"""
    ShapeVariation(cfg::ShapeVariationConfig)

A configured shape variation with its evaluator `kind` (`JESShape`,
`JERShape` or `ScaleShape`; correction sets loaded, expressions compiled).
"""
struct ShapeVariation{K}
    config::ShapeVariationConfig
    kind::K
end

function ShapeVariation(cfg::ShapeVariationConfig)
    cfg.kind === :jes && return ShapeVariation(cfg, JESShape(cfg))
    cfg.kind === :jer && return ShapeVariation(cfg, JERShape(cfg))
    cfg.kind === :scale && return ShapeVariation(cfg, ScaleShape(cfg))
    throw(ArgumentError("unknown shape variation kind $(cfg.kind)"))
end
