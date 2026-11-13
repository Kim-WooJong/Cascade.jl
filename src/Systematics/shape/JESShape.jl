"""
    JESShape(cfg::ShapeVariationConfig)

Jet energy scale variation: `uncertainty` is the correction (inputs
`JetEta, JetPt`) giving the relative uncertainty `u`; objects are scaled by
`1 + u` (up) and `1 - u` (down). NanoAOD jets are already JEC-corrected, so
`u` is evaluated at the stored (unsmeared) jet pt and eta.
"""
struct JESShape
    uncertainty::Union{Correction,CompoundCorrection}
end

JESShape(cfg::ShapeVariationConfig) =
    JESShape(shape_correction(cfg.params["corrections"], cfg.params["source"], mapped_inputs(cfg, ["JetEta", "JetPt"])))
