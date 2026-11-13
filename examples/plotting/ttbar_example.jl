# Plots and tables from the prior ttbar e-mu control outputs (read-only) on gate.
# Usage: bash ~/packages/rootplots-gate.sh --project=<Cascade checkout> <abs path>/examples/plotting/ttbar_example.jl <ttbar_ctrl dir> <outdir>
using TOML: TOML
using Cascade.Plotting
include(joinpath(@__DIR__, "lib", "read_ttbar_tsv.jl"))
include(joinpath(@__DIR__, "lib", "read_ttbar_cutflow.jl"))
include(joinpath(@__DIR__, "lib", "ttbar_scale_factors.jl"))
include(joinpath(@__DIR__, "lib", "load_ttbar_templates.jl"))
include(joinpath(@__DIR__, "lib", "load_ttbar_cutflow.jl"))
include(joinpath(@__DIR__, "lib", "illustrative_normfactor.jl"))
include(joinpath(@__DIR__, "lib", "illustrative_postfit.jl"))
include(joinpath(@__DIR__, "lib", "check_reference.jl"))
include(joinpath(@__DIR__, "lib", "write_table_files.jl"))
include(joinpath(@__DIR__, "lib", "run_ttbar_example.jl"))
run_ttbar_example(ARGS[1], ARGS[2]) || exit(1)
