# Compare Cascade.Corrections with correctionlib oracle outputs and measure
# evaluation throughput (gate).
#   julia --project=. tools/oracle/compare_oracle.jl ORACLE_DIR
using Cascade
include(joinpath(@__DIR__, "..", "..", "test", "corrections", "oracle_compare.jl"))
include(joinpath(@__DIR__, "..", "..", "test", "corrections", "measure_throughput.jl"))
include(joinpath(@__DIR__, "report_oracle.jl"))

report_oracle(stdout, ARGS[1])
