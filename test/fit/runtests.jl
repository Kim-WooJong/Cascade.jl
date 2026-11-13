using Test
using LinearAlgebra
using Random
using JSON3
using Cascade.Fit

include("workspaces.jl")
include("test_interpolation.jl")
include("test_build_model.jl")
include("test_nll.jl")
include("test_fit_analytic.jl")
include("test_asymptotics_analytic.jl")
include("test_pulls_impacts_yields.jl")
include("test_pyhf_crosscheck.jl")
include("store_fixture.jl")
include("test_store_fit.jl")
include("test_channel_overlap.jl")
include("test_store_pyhf.jl")
