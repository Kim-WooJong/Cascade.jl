using Test
using Cascade
include("isolated_area_command.jl")

# These dependency-free recording fixtures require their own Main namespace.
# Legacy package areas retain their existing shared fixtures and include order.
const ISOLATED_TEST_AREAS = Set([
    "benchmark_telemetry", "event_ranges", "execution_options", "modern_counting",
    "named_stages", "no_checkpoint_file_work", "node_memo",
    "reusable_shared_offsets_default", "skim_entrycount",
    "stable_selection_kernels", "stream_plan_branch_lookup", "window_accounting",
    "window_io", "windowed_reusable_decoder", "windowed_selection",
])

for area in filter(d -> isdir(joinpath(@__DIR__, d)), readdir(@__DIR__))
    f = joinpath(@__DIR__, area, "runtests.jl")
    isfile(f) || continue
    @testset "$area" begin
        if area in ISOLATED_TEST_AREAS
            # Preserve child stdout/stderr and turn any nonzero exit/signal into
            # a parent failure; this count is an area, not scientific assertions.
            @test success(run(ignorestatus(isolated_area_command(f))))
        else
            include(f)
        end
    end
end
