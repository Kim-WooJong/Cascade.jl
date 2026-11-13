# List kept events (source path, 1-based entry) for sf_oracle.py.
# Usage: julia --project=. tools/oracle/sf_dump_events.jl WORKDIR OUT.tsv MAX SAMPLE [SAMPLE...]
# MAX > 0 uses a chunk stride targeting approximately MAX events over the samples.
using Cascade.IO, Cascade.Selection
include(joinpath(@__DIR__, "..", "..", "test", "systematics", "weights", "sf_artifacts.jl"))
include(joinpath(@__DIR__, "..", "..", "test", "systematics", "weights", "sf_dump_events.jl"))

sf_dump_events(ARGS[1], ARGS[2], parse(Int, ARGS[3]), ARGS[4:end])
