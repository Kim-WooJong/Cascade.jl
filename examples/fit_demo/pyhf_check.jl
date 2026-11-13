# Cross-check a Cascade fit workspace with pyhf (external oracle, gate LCG view). Usage:
#   julia --project=<Cascade> examples/fit_demo/pyhf_check.jl <workdir>/fit/workspace.json
using Cascade, JSON3, LinearAlgebra
include(joinpath(@__DIR__, "lib", "pyhf_compare.jl"))
exit(pyhf_compare(ARGS[1]) ? 0 : 1)
