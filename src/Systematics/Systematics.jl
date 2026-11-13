"""
    Cascade.Systematics

Systematic variations. Weight type (`weights/`): scale factors and per-event
weights from correctionlib sets, configured in the `[corrections]` section of
the analysis TOML and applied in the `correct` step by the hook
`apply_corrections` (`[hooks] correct = "Cascade.Systematics.apply_corrections"`).
The hook returns the weight columns `"nominal"`, `"<name>Up"`, `"<name>Down"`
consumed by the histogram step. See `parse_corrections` for the schema.
Shape type (`shape/`, submodule `Systematics.Shape`): object-kinematics
variations (JES, JER, lepton scale), see `Shape`.
"""
module Systematics

using ..Config
using ..IO
using ..Selection
using ..Corrections
using ..Histograms

include("shape/Shape.jl")

include("weights/ObjectScaleFactor.jl")
include("weights/EventWeight.jl")
include("weights/FlatWeight.jl")
include("weights/TriggerEfficiency.jl")
include("weights/TriggerOR.jl")
include("weights/CorrectionsSpec.jl")
include("weights/CorrectionInput.jl")
include("weights/WeightFactors.jl")
include("weights/BranchReader.jl")
include("weights/vector_members.jl")
include("weights/theory_member_weights.jl")
include("weights/theory_band.jl")
include("weights/verify_theory_extraction.jl")
include("weights/reduce_theory.jl")
include("weights/parse_corrections.jl")
include("weights/parse_trigger_or.jl")
include("weights/cached_correctionset.jl")
include("weights/reset_correction_cache!.jl")
include("weights/bind_inputs.jl")
include("weights/eval_vector_expression.jl")
include("weights/output_column_index.jl")
include("weights/object_expression.jl")
include("weights/evaluate_term.jl")
include("weights/object_factors.jl")
include("weights/trigger_or_ratio.jl")
include("weights/trigger_or_factors.jl")
include("weights/event_factors.jl")
include("weights/flat_factors.jl")
include("weights/combine_weights.jl")
include("weights/correction_weights.jl")
include("weights/apply_corrections.jl")

export ObjectScaleFactor, EventWeight, FlatWeight, TriggerEfficiency, TriggerOR, CorrectionsSpec, CorrectionInput, WeightFactors,
       verify_theory_extraction, vector_members, theory_member_weights, reduce_theory, BranchReader, parse_corrections, cached_correctionset, bind_inputs, eval_vector_expression,
       output_column_index, object_expression, object_factors, event_factors, flat_factors,
       combine_weights, correction_weights, apply_corrections, trigger_or_ratio, trigger_or_factors

end # module
