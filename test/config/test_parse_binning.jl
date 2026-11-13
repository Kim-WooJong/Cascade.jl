module TestParseBinning
using Test, Cascade.Config

@testset "parse_binning" begin
    # Bit-identical to the constructions of the reference ttbar code.
    @test parse_binning(Dict("range" => [35.0, 10.0, 205.0])) == collect(35.0:10.0:205.0)
    @test parse_binning(Dict("linspace" => [-2.4, 2.4, 20])) == collect(range(-2.4, 2.4; length = 21))
    @test parse_binning(Dict("range" => [0.5, 1.0, 7.5])) == collect(0.5:1.0:7.5)
    @test parse_binning(Dict("edges" => [0, 1, 5])) == [0.0, 1.0, 5.0]
    @test_throws ArgumentError parse_binning(Dict("edges" => [0, 1], "range" => [0, 1, 2]))
    @test_throws ArgumentError parse_binning(Dict{String,Any}())
    @test_throws ArgumentError parse_binning(Dict("edges" => [1.0, 1.0, 2.0]))
    @test_throws ArgumentError parse_binning(Dict("edges" => [1.0]))
end
end
