"""
    Cascade.Systematics.Shape

Shape (object-kinematics) systematic variations: jet energy scale (`jes`),
jet energy resolution smearing (`jer`) and generic per-object scale factors
(`scale`) defined by `[[shape_variations]]` (see `Config.shape_variations`).
For one chunk, `shape_columns` turns the columns read by the selection into
varied columns (`<collection>_pt`, `_mass`, optionally MET) per label
`<name>Up` / `<name>Down` (and `nominal` if JER smearing of the nominal is
enabled); `Selection.run_selection_variations` re-runs object and event
selection on them. Correction sets are evaluated with `Cascade.Corrections`.
"""
module Shape

using SHA: sha256

using ...Config
using ...IO: Jagged
using ...Objects: deltaR
using ...Selection: compile_object_expression, evaluate_object_expression
using ...Corrections: CorrectionSet, Correction, CompoundCorrection, load_correctionset, evaluate

include("shape_correction.jl")
include("mapped_inputs.jl")
include("JESShape.jl")
include("JERShape.jl")
include("ScaleShape.jl")
include("ShapeVariation.jl")
include("shape_variations_for.jl")
include("matched_genjet_pt.jl")
include("jes_factors.jl")
include("jer_factors.jl")
include("scale_factors.jl")
include("shape_factors.jl")
include("scale_column.jl")
include("propagate_met.jl")
include("shape_inputs.jl")
include("ShapePlan.jl")
include("shape_plan.jl")
include("shape_columns.jl")

export JESShape, JERShape, ScaleShape, ShapeVariation, ShapePlan, shape_correction,
       shape_variations_for, matched_genjet_pt, jes_factors, jer_factors, scale_factors,
       shape_factors, scale_column, propagate_met, shape_inputs, shape_plan, shape_columns

end # module
