@testset "cutflow" begin
    stages = ["all", "two_leptons", "njet_ge1"]
    cf = Cutflow(stages, Dict("A" => [100.0, 50.0, 10.0], "B" => [40.0, 4.0, 1.0], "D" => [200.0, 60.0, 12.0]);
                 sumw2=Dict("A" => [100.0, 50.0, 10.0]), data=["D"])
    @test cf.columns == ["A", "B", "D"] && cf.is_data == [false, false, true]
    @test cf.sumw2[:, 2] == zeros(3)
    c = fixture_config()
    gc = group_cutflow(cf, c; scale=Dict("A" => 0.5, "B" => 2.0))
    @test gc.columns == ["Bkg B", "t#bar{t}", "Data"] && gc.is_data == [false, false, true]
    @test gc.sumw[:, 1] == [80.0, 8.0, 2.0] && gc.sumw[:, 2] == [50.0, 25.0, 5.0] && gc.sumw[:, 3] == [200.0, 60.0, 12.0]
    @test gc.sumw2[:, 2] == [25.0, 12.5, 2.5]
    @test_throws ArgumentError group_cutflow(cf, StackConfig([SampleGroup("x", "#000000", ["Q"])], String[]))
    tab = cutflow_table(gc; labels=["All", "2 leptons", "#geq1 jet"])
    @test tab.header == ["Selection", "Bkg B", "t#bar{t}", "Total MC", "Data", "Eff. (%)"]
    txt = render_table(tab)
    @test occursin("≥1 jet", txt) && occursin("130.0", txt) && occursin("25.4", txt)   # 33 / 130
    @test tab.rows[1][end] == ""
    @test_throws ArgumentError Cutflow(["a"], ["x"], zeros(2, 1))
    @test_throws ArgumentError Cutflow(String[], ["x"], zeros(0, 1))
end
