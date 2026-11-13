# Cascade.Systematics tests (entry: includes only).
include(joinpath("weights", "runtests.jl"))
isfile(joinpath(@__DIR__, "shape", "runtests.jl")) && include(joinpath("shape", "runtests.jl"))
