# Every plot and table type from synthetic histograms.
# Usage: bash ~/packages/rootplots-gate.sh --project=<Cascade checkout> <abs path>/examples/plotting/synthetic_example.jl <outdir>
using Cascade.Plotting
include(joinpath(@__DIR__, "lib", "synthetic_templates.jl"))
include(joinpath(@__DIR__, "lib", "synthetic_nuisances.jl"))
include(joinpath(@__DIR__, "lib", "write_table_files.jl"))
include(joinpath(@__DIR__, "lib", "run_synthetic_example.jl"))
run_synthetic_example(ARGS[1])
