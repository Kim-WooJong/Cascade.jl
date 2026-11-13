@testset "postfit interface" begin
    c = StackConfig([SampleGroup("Z", "#1F77B4", ["DY1", "DY2"]), SampleGroup("tt", "#C5001A", ["TT"])], ["D"])
    fy = FitYields(EDGES, Dict("DY1" => [1.0, 2.0, 3.0], "DY2" => [1.0, 0.0, 0.0], "TT" => [10.0, 20.0, 30.0]),
                   [1.0, 2.0, 3.0]; errors_low=[0.5, 1.0, 1.5], yield_errors=Dict("TT" => 4.0), total_error=5.0)
    g = postfit_groups(fy, c)
    @test [x.name for x in g] == ["Z", "tt"] && g[1].nominal.sumw == [2.0, 2.0, 3.0]
    @test all(iszero, g[1].nominal.sumw2)
    b = postfit_band(fy)
    @test b.prediction == [12.0, 22.0, 33.0] && b.high == [1.0, 2.0, 3.0] && b.low == [0.5, 1.0, 1.5]
    @test all(iszero, b.stat) && b.label == "Postfit unc."
    bygroup = FitYields(EDGES, Dict("Z" => [1.0, 1.0, 1.0], "tt" => [2.0, 2.0, 2.0]), [0.1, 0.1, 0.1])
    @test postfit_groups(bygroup, c)[2].nominal.sumw == [2.0, 2.0, 2.0]
    @test_throws ArgumentError postfit_groups(FitYields(EDGES, Dict("XX" => [1.0, 1, 1], "TT" => [1.0, 1, 1]), [0.0, 0, 0]), c)
    @test_throws ArgumentError postfit_groups(FitYields(EDGES, Dict("TT" => [1.0, 1, 1]), [0.0, 0, 0]), c)
    @test_throws ArgumentError FitYields(EDGES, Dict("TT" => [1.0, 1]), [0.0, 0, 0])
    @test_throws ArgumentError FitYields(EDGES, Dict("TT" => [1.0, 1, 1]), [-1.0, 0, 0])

    tab = render_table(yield_table(fy, c; data=binned_hist(EDGES, [12, 22, 33], [12, 22, 33])))
    @test occursin("tt", tab) && occursin("± 4.0", tab) && occursin("n/a", tab) && occursin("± 5.0", tab)
    @test occursin("67.0", tab)
end
