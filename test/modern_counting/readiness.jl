# Stdlib boundary entry point; no event analysis.
include("test_modern_counting.jl")
using TOML
const B = TestModernCounting.Boundary
const R = normpath(joinpath(@__DIR__, "../.."))
cfg = B.parse_analysis(TOML.parsefile(joinpath(R,"analyses/ttbar_emu/modern_counting.toml")); dir=joinpath(R,"analyses/ttbar_emu"))
TOML.print(stdout, B.counting_readiness(cfg))
