# Focused config tests: conditional default of execution.reusable_shared_offsets.
# Standalone: stdlib only, production Config source files, no Cascade load, no ROOT input.
using Test
module SharedOffsetsDefault
const ROOT = normpath(joinpath(@__DIR__, "../.."))
struct AnalysisConfig
    raw::Dict{String,Any}
    variations::Vector{Any}
end
AnalysisConfig(raw) = AnalysisConfig(Dict{String,Any}(raw), Any[])
for file in ("TriggerConfig", "DataQualityConfig", "column_readers", "decode_options",
             "windowed_selection", "memory_handoff", "streaming_selection_options", "memoization_options",
             "checkpoint_options", "event_ranges", "validate_keys")
    include(joinpath(ROOT, "src", "Config", file * ".jl"))
end
errmsg(f) = try f(); "ok" catch e; sprint(showerror, e) end
end
const SOD = SharedOffsetsDefault
ex(d) = Dict{String,Any}("execution" => Dict{String,Any}(d))
const DEC = Dict{String,Any}("windowed_selection" => true, "windowed_reusable_decoder" => true)

@testset "reusable_shared_offsets conditional default" begin
    @testset "omitted: off without the reusable decoder route" begin
        @test SOD.reusable_shared_offsets(Dict()) === false
        @test SOD.reusable_shared_offsets(ex(Dict())) === false
        @test SOD.reusable_shared_offsets(ex(Dict("windowed_selection" => true))) === false
        @test SOD.reusable_shared_offsets(ex(Dict("windowed_selection" => true, "windowed_reusable_decoder" => false))) === false
        @test SOD.reusable_shared_offsets(ex(Dict("event_range_selection" => true))) === false
        @test SOD.reusable_shared_offsets(SOD.AnalysisConfig(Dict())) === false
        # no other execution default is changed by this resolver
        @test SOD.windowed_selection(Dict()) === false && SOD.windowed_reusable_decoder(Dict()) === false
        @test SOD.event_range_selection(Dict()) === false
        @test SOD.validate_keys(ex(Dict())) isa Dict
    end
    @testset "omitted: on exactly on the effective reusable decoder route" begin
        @test SOD.reusable_shared_offsets(ex(DEC)) === true
        @test SOD.reusable_shared_offsets(SOD.AnalysisConfig(ex(DEC))) === true
        @test SOD.validate_keys(ex(DEC)) isa Dict
        # implicit default == explicit true (the R14-validated behavior)
        @test SOD.reusable_shared_offsets(ex(DEC)) === SOD.reusable_shared_offsets(ex(merge(DEC, Dict("reusable_shared_offsets" => true))))
        # decoder relations are still validated (unchanged decoder errors)
        @test_throws ArgumentError SOD.reusable_shared_offsets(ex(Dict("windowed_reusable_decoder" => true)))
        @test SOD.reusable_shared_offsets(ex(Dict("windowed_reusable_decoder" => true)); validate_relations = false) === true
    end
    @testset "explicit values" begin
        @test SOD.reusable_shared_offsets(ex(merge(DEC, Dict("reusable_shared_offsets" => false)))) === false
        @test SOD.reusable_shared_offsets(ex(Dict("reusable_shared_offsets" => false))) === false
        @test SOD.validate_keys(ex(merge(DEC, Dict("reusable_shared_offsets" => false)))) isa Dict
        @test SOD.reusable_shared_offsets(ex(merge(DEC, Dict("reusable_shared_offsets" => true)))) === true
        for bad in (Dict("reusable_shared_offsets" => true),
                    Dict("windowed_selection" => true, "reusable_shared_offsets" => true),
                    Dict("windowed_selection" => true, "windowed_reusable_decoder" => false, "reusable_shared_offsets" => true))
            @test occursin("requires execution.windowed_reusable_decoder = true", SOD.errmsg(() -> SOD.reusable_shared_offsets(ex(bad))))
            @test_throws ArgumentError SOD.validate_keys(ex(bad))
        end
        for value in (1, 0, "true", "false", nothing, 1.0, missing)
            @test occursin("must be boolean", SOD.errmsg(() -> SOD.reusable_shared_offsets(ex(merge(DEC, Dict{String,Any}("reusable_shared_offsets" => value))))))
            @test_throws ArgumentError SOD.validate_keys(ex(merge(DEC, Dict{String,Any}("reusable_shared_offsets" => value))))
            @test_throws ArgumentError SOD.validate_keys(Dict("profiles" => Dict("inactive" => ex(Dict{String,Any}("reusable_shared_offsets" => value)))))
        end
    end
    @testset "profiles: relations deferred to the merged profile" begin
        base_on = ex(DEC)
        # inherited decoder on, profile disables decoder, shared omitted: no spurious error, resolves off
        p = merge(base_on, Dict{String,Any}("profiles" => Dict("off" => ex(Dict("windowed_reusable_decoder" => false)))))
        @test SOD.validate_keys(p) === p
        merged = ex(merge(DEC, Dict("windowed_reusable_decoder" => false)))
        @test SOD.reusable_shared_offsets(merged) === false
        # inherited explicit true with a profile that disables the decoder: rejected (also when inactive)
        bad = merge(ex(merge(DEC, Dict("reusable_shared_offsets" => true))),
            Dict{String,Any}("profiles" => Dict("inactive" => ex(Dict("windowed_reusable_decoder" => false)))))
        @test_throws ArgumentError SOD.validate_keys(bad)
        # profile enables the decoder over a plain base: shared follows it implicitly
        q = merge(ex(Dict("windowed_selection" => true)), Dict{String,Any}("profiles" => Dict("dec" => ex(Dict("windowed_reusable_decoder" => true)))))
        @test SOD.validate_keys(q) === q
        @test SOD.reusable_shared_offsets(ex(Dict("windowed_selection" => true, "windowed_reusable_decoder" => true))) === true
        # profile explicitly disables sharing over a decoder-on base
        r = merge(base_on, Dict{String,Any}("profiles" => Dict("copy" => ex(Dict("reusable_shared_offsets" => false)))))
        @test SOD.validate_keys(r) === r
        @test SOD.reusable_shared_offsets(ex(merge(DEC, Dict("reusable_shared_offsets" => false)))) === false
        # overlay with an omitted flag never throws on its own
        @test SOD.validate_keys(Dict("profiles" => Dict("plain" => ex(Dict("windowed_selection" => true))))) isa Dict
        @test SOD.reusable_shared_offsets(Dict("execution" => Dict("windowed_reusable_decoder" => true)); validate_relations = false) === true
    end
    @testset "source contracts: runtime resolution site and low-level defaults unchanged" begin
        root = SOD.ROOT
        chunk = read(joinpath(root, "src/Pipeline/memory_chunk_helpers.jl"), String)
        pipe = read(joinpath(root, "src/Pipeline/stream_selection.jl"), String)
        io = read(joinpath(root, "src/IO/stream_reusable_decoder.jl"), String)
        @test occursin("shared_offsets = reusable && Config.reusable_shared_offsets(cfg)", chunk)
        @test count("shared_offsets::Bool=false", pipe) == 2
        @test occursin("share_window_offsets::Bool = false)", io)
        for (dir, _, files) in walkdir(joinpath(root, "analyses")), f in files
            endswith(f, ".toml") || continue
            @test !occursin("reusable_shared_offsets", read(joinpath(dir, f), String))
        end
    end
end
