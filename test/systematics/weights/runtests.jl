# Weight-type systematics: [corrections] scale factors in the correct step.
module SystematicsWeightsTests

using Test
using Cascade

include("fixtures.jl")
include("test_eval_vector_expression.jl")
include("test_parse_corrections.jl")
include("test_correction_weights.jl")
include("test_theory_weights.jl")
include("test_theory_pipeline.jl")
include("test_theory_review.jl")
include("test_theory_partial.jl")
include("test_theory_contract.jl")
include("test_theory_real.jl")
include("test_trigger_or.jl")
include("test_pipeline_corrections.jl")
include("test_correction_cache.jl")
include("test_ttbar_sf_real.jl")
include("test_sf_oracle_real.jl")

end # module
