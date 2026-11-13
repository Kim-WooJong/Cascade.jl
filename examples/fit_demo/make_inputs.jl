# Write the synthetic inputs of analyses/fit_demo. Usage:
#   julia --project=<Cascade> examples/fit_demo/make_inputs.jl [outdir]   (default analyses/fit_demo/inputs)
using Random
using Cascade.IO: write_column_file
include(joinpath(@__DIR__, "lib", "write_fit_demo_inputs.jl"))
println(write_fit_demo_inputs(get(ARGS, 1, joinpath(@__DIR__, "..", "..", "analyses", "fit_demo", "inputs"))))
