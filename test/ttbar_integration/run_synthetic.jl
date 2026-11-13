using Test, Cascade
include(joinpath(@__DIR__,"../config/runtests.jl"))
include(joinpath(@__DIR__,"../pipeline/test_shape_pipeline.jl"))
include(joinpath(@__DIR__,"../pipeline/test_combined_systematics.jl"))
include(joinpath(@__DIR__,"../pipeline/test_theory_shape.jl"))
