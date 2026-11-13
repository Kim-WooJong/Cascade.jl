"""
    JERShape(cfg::ShapeVariationConfig)

Jet energy resolution smearing (hybrid method, correctionlib `JERSmear`):
`resolution` (inputs `JetEta, JetPt, Rho`), `scale_factor` (inputs
`JetEta[, JetPt], systematic`), `smear` (inputs `JetPt, JetEta, GenPt, Rho,
EventID, JER, JERSF`). Column names: `rho` (event), `event` (event id),
`genjet` (GenJet prefix), `genjet_index` (field of the jet collection, 0-based
index into the event's GenJets, < 0 if none). Gen matching: `deltaR < match_dr`
and `|pt - genpt| < match_nsigma * JER * pt`. `nominal`: smear the nominal too.
"""
struct JERShape
    resolution::Union{Correction,CompoundCorrection}
    scale_factor::Union{Correction,CompoundCorrection}
    sf_has_pt::Bool
    smear::Union{Correction,CompoundCorrection}
    rho::String
    event::String
    genjet::String
    genjet_index::String
    match_dr::Float64
    match_nsigma::Float64
    nominal::Bool
end

function JERShape(cfg::ShapeVariationConfig)
    p = cfg.params
    res = shape_correction(p["corrections"], p["resolution"], mapped_inputs(cfg, ["JetEta", "JetPt", "Rho"]))
    sf = shape_correction(p["corrections"], p["scale_factor"])
    sfin = [v.name for v in sf.inputs]
    sfin in (mapped_inputs(cfg, ["JetEta", "JetPt", "systematic"]), mapped_inputs(cfg, ["JetEta", "systematic"])) ||
        throw(ArgumentError("JER scale factor '$(p["scale_factor"])' has unsupported inputs $sfin"))
    smear = shape_correction(p["smear_file"], p["smear"],
                             mapped_inputs(cfg, ["JetPt", "JetEta", "GenPt", "Rho", "EventID", "JER", "JERSF"]))
    return JERShape(res, sf, length(sfin) == 3, smear, String(p["rho"]), String(p["event"]), String(p["genjet"]),
                    String(p["genjet_index"]), Float64(p["match_dr"]), Float64(p["match_nsigma"]),
                    p["nominal"] === true)
end
