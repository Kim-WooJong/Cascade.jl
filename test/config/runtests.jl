# Cascade.Config tests (entry: includes only).
include("test_parse_binning.jl")
include("test_substitute_paths.jl")
include("test_load_analysis.jl")
include("test_validate_analysis.jl")
include("test_canonical_hash.jl")
include("test_canonical_hash_bytes.jl")
include("test_shape_variations.jl")
include("test_profiles.jl")
include("test_sf_profile_contract.jl")
include("test_sample_annotations.jl")
include("test_integration_profile.jl")
module TestExecutionOptimizations
using Test, Cascade.Config
include("test_execution_optimizations.jl")
end
