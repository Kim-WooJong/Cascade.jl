"""Reject subsets that would require silently removing scientific declarations."""
function validate_reduced_subset(cfg, samples)
    selected = Set(s.name for s in samples)
    selected == Set(s.name for s in cfg.samples) && return nothing
    haskey(cfg.raw, "fit") && error("reduced sample subsets with [fit] are unsupported; supply an explicitly revised complete analysis instead of silently shrinking its model/data")
    for term in theory_weights(cfg)
        all(name -> name in selected, term["samples"]) || error("reduced subset excludes a declared theory sample; scientific declarations are not silently removed")
    end
    for variation in shape_variations(cfg)
        all(name -> name in selected, variation.samples) || error("reduced subset excludes an explicit shape sample; scientific declarations are not silently removed")
    end
    return nothing
end
