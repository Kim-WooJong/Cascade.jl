# Parent-only single Julia subject: stdlib fixtures, lowering comparison, real trace.
# No Cascade import, package installation, ROOT inputs, or scientific benchmark.
using Test
const REPO = normpath(joinpath(@__DIR__, "..", ".."))

# The unit fixture temporarily selects private trace paths. Preserve runner settings.
include(joinpath(@__DIR__, "runtests.jl"))

module BaselineLowering
struct OrderedWindow end
include(joinpath(@__DIR__, "..", "..", "artifacts", "cascade-benchmark-telemetry-20261111", "preimage", "run_no_checkpoints.jl"))
end
module CurrentLowering
struct OrderedWindow end
include(joinpath(@__DIR__, "..", "..", "src", "Pipeline", "run_no_checkpoints.jl"))
end
@testset "disabled-path closure lowering" begin
    original = string(only(code_lowered(BaselineLowering.run_no_checkpoints, NTuple{4,Any})))
    revised = string(only(code_lowered(CurrentLowering._run_no_checkpoints_traced, NTuple{4,Any})))
    baseline_boxes = length(collect(eachmatch(r"Core.Box", original)))
    current_boxes = length(collect(eachmatch(r"Core.Box", revised)))
    println("LOWERING_BOXES baseline=", baseline_boxes, " current=", current_boxes)
    @test current_boxes <= baseline_boxes
    # Nested work/phase closures are also printed for concrete review if needed.
    println("LOWERING_CURRENT_BEGIN\n", revised, "\nLOWERING_CURRENT_END")
end

# Explicit clock IDs come from Python's time constants on this host, not guesses.
function clockns(clock_id)
    value = Ref{NTuple{2,Int64}}((0,0))
    rc = ccall(:clock_gettime, Cint, (Cint, Ref{NTuple{2,Int64}}), clock_id, value)
    rc == 0 || error("clock_gettime failed")
    return value[][1] * 1000000000 + value[][2]
end
selected = parse(Int, ARGS[1]); other = parse(Int, ARGS[2])
lo = clockns(selected); stamp = time_ns(); hi = clockns(selected)
otherlo = clockns(other); otherstamp = time_ns(); otherhi = clockns(other)
println("UV_CLOCK_NS=", stamp)
println("CLOCK_BRACKET=", lo, ",", stamp, ",", hi)
println("OTHER_CLOCK_BRACKET=", otherlo, ",", otherstamp, ",", otherhi)
@test lo <= stamp <= hi
if Sys.isapple()
    @test !(otherlo <= otherstamp <= otherhi)
end

# Exercise real production writer, concurrency, nested spans and finally failure.
# This is a library integration subject, not the unavailable full Cascade chain.
mktempdir() do science
    BT.benchmark_span(:no_checkpoints_run, science) do
        BT.benchmark_span(() -> nothing, :skim, science)
        BT.benchmark_span(() -> nothing, :preparation, science)
        BT.benchmark_span(:chain_merge, science) do
            @sync for chunk in 1:4
                Threads.@spawn begin
                    for phase in (:select, :correct, :histogram)
                        BT.benchmark_span(() -> yield(), phase, science; sample="synthetic", chunk)
                    end
                end
            end
            BT.benchmark_span(() -> nothing, :merge, science)
        end
        BT.benchmark_span(() -> nothing, :publication, science)
    end
    @test_throws ErrorException BT.benchmark_span(() -> error("synthetic original error"), :failure_fixture, science)
end
println("PARENT_GATE_COMPLETED")
