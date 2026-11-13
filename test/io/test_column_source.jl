module TestColumnSource
using Test, Cascade.IO

@testset "ColumnFileSource / open_source" begin
    mktempdir() do d
        p = joinpath(d, "ev.cols")
        write_column_file(p, Dict{String,Any}("genWeight" => Float32[1, -2, 3.5], "Jet_pt" => Jagged([Float32[1], Float32[], Float32[2, 3]])))
        src = open_source("cols", p)
        @test src isa AbstractEventSource && src isa ColumnFileSource
        @test nevents(src) == 3
        @test sort(column_names(src)) == ["Jet_pt", "genWeight"]
        c = read_columns(src, ["Jet_pt"])
        @test c["Jet_pt"].offsets == [0, 1, 1, 3]
        @test gen_weight_sum(src) == 2.5
        @test source_signature(src)["format"] == "cols"
        @test_throws KeyError read_columns(src, ["nope"])
        write_column_file(p, Dict{String,Any}("x" => [1.0]); meta = Dict("gen_weight_sum" => 42.0))
        @test gen_weight_sum(open_source("cols", p)) == 42.0
    end
    @test "nanoaod" in source_formats() && "cols" in source_formats()
    @test_throws ArgumentError open_source("nope", "x")
end
end
