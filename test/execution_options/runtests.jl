using Test
module ExecutionOptionsHarness
using Test
struct AnalysisConfig
    raw::Dict{String,Any}
end
const ROOT = normpath(joinpath(@__DIR__, "../.."))
for name in ("column_readers", "decode_options", "windowed_selection", "memory_handoff",
             "memoization_options", "checkpoint_options", "event_ranges", "streaming_selection_options", "validate_keys")
    include(joinpath(ROOT,"src","Config",name*".jl"))
end
include(joinpath(ROOT,"test","config","test_execution_optimizations.jl"))
end
