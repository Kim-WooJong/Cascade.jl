# Standalone stdlib-only tests. No Cascade import, ROOT inputs or package setup.
using Test
module TelemetryFixture
# Tiny deterministic JSON encoder for the production trace writer's scalar records.
module JSON3
escape(s) = replace(replace(replace(String(s), "\\" => "\\\\"), "\"" => "\\\""), "\n" => "\\n")
encode(x::Nothing) = "null"
encode(x::Integer) = string(x)
encode(x::AbstractString) = "\"" * escape(x) * "\""
write(x::NamedTuple) = "{" * join((encode(string(k)) * ":" * encode(v) for (k,v) in pairs(x)), ",") * "}"
end
include(joinpath(@__DIR__, "..", "..", "src", "Pipeline", "benchmark_telemetry.jl"))
end
const BT = TelemetryFixture

@testset "bounded opt-in telemetry" begin
    mktempdir() do dir
        scientific = joinpath(dir, "science")
        trace_dir = mkdir(joinpath(dir, "trace"))
        withenv("CASCADE_BENCHMARK_TRACE_DIR" => nothing) do
            @test BT.benchmark_span(() -> 17, :disabled, scientific) == 17
            @test isempty(readdir(trace_dir))
        end
        for bad in ("relative", scientific, joinpath(dir, "missing"))
            withenv("CASCADE_BENCHMARK_TRACE_DIR" => bad) do
                @test_throws ArgumentError BT.benchmark_span(() -> 1, :bad, scientific)
            end
        end
        mkdir(scientific)
        inside = mkdir(joinpath(scientific, "trace"))
        withenv("CASCADE_BENCHMARK_TRACE_DIR" => inside) do
            @test_throws ArgumentError BT.benchmark_span(() -> 1, :bad, scientific)
        end
        withenv("CASCADE_BENCHMARK_TRACE_DIR" => trace_dir,
                "CASCADE_BENCHMARK_TRACE_MAX_RECORDS" => "bogus") do
            @test_throws ArgumentError BT.benchmark_span(() -> 1, :bad, scientific)
        end
        withenv("CASCADE_BENCHMARK_TRACE_DIR" => trace_dir) do
            @test BT.benchmark_span(() -> 23, :select, scientific; sample="s",chunk="c") == 23
            @test_throws ErrorException BT.benchmark_span(() -> error("fixture"), :correct, scientific)
            @sync for i in 1:4
                @async BT.benchmark_span(() -> yield(), :histogram, scientific; sample="s",chunk=i)
            end
            files = readdir(trace_dir; join=true)
            @test length(files) == 1
            lines = readlines(only(files))
            @test length(lines) == 12
            @test count(l -> occursin("\"event\":\"begin\"", l), lines) == 6
            @test count(l -> occursin("\"status\":\"failed\"", l), lines) == 1
            @test all(l -> occursin("\"task_id\":", l) && occursin("\"monotonic_ns\":", l), lines)
            @test_throws ArgumentError BT.benchmark_span(() -> nothing, :large, scientific; sample=repeat("x",4097))
            # Instrumentation failures must propagate, never disappear.
            BT.BENCHMARK_TRACE[].limit = 12
            @test_throws ErrorException BT.benchmark_span(() -> nothing, :overflow, scientific)
        end
        close(BT.BENCHMARK_TRACE[].io)
        BT.BENCHMARK_TRACE[] = nothing
    end
end
