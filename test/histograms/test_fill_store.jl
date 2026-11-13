module TestFillStore
using Test, Cascade.Config, Cascade.Histograms

@testset "fill_store! regions x variations x variables" begin
    h1 = HistogramConfig("x", [0.0, 1.0, 2.0], ["a", "b"], "true", String[], "x")
    h2 = HistogramConfig("y", [0.0, 10.0], ["c"], "true", ["tight"], "y")
    values = Dict{String,Any}("x" => [[0.5, 1.5, NaN], [1.5, 0.5, 0.5]], "y" => [[1.0, 2.0, 3.0]])
    regions = ["loose" => [true, true, true], "tight" => [false, true, true]]
    weights = [NOMINAL => [1.0, 2.0, 3.0], "sUp" => [2.0, 4.0, 6.0]]
    s = fill_store!(HistogramStore(), "smp", [h1, h2], values, regions, weights)
    @test length(s) == 2 * 2 + 2           # y only in "tight"
    @test s["loose", "smp", NOMINAL, "x"].sumw == [1.0 + 2.0 + 3.0, 1.0 + 2.0]
    @test s["tight", "smp", NOMINAL, "x"].sumw == [2.0 + 3.0, 2.0]
    @test s["tight", "smp", "sUp", "y"].sumw == [10.0]
    @test !haskey(s, HistKey("loose", "smp", NOMINAL, "y"))
end
end
