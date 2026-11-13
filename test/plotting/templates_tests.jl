@testset "templates" begin
    t = fixture_templates()
    @test sort(collect(keys(t))) == ["A", "B", "D"]
    @test t["B"].variations["jesUp"].sumw == [6.0, 5.0, 5.0]       # Hist1D adapter
    @test isempty(t["D"].variations)
    @test_throws ArgumentError collect_templates(Dict(("X", "jesUp") => (EDGES, [1, 1, 1], [1, 1, 1])))
    @test_throws ArgumentError collect_templates([("X", "nominal") => (EDGES, [1, 1, 1], [1, 1, 1]),
                                                  ("X", "nominal") => (EDGES, [1, 1, 1], [1, 1, 1])])
    @test_throws ArgumentError collect_templates(Dict(("X", "nominal") => (EDGES, [1, 1, 1], [1, 1, 1]),
                                                      ("X", "up") => ([0.0, 1.0], [1], [1])))

    m = merge_samples(t, ["A", "B"]; name="AB")
    @test m.name == "AB" && m.nominal.sumw == [15.0, 25.0, 35.0]
    @test m.variations["jesDown"].sumw == [14.0, 27.0, 36.0]         # B contributes its nominal
    @test m.variations["jesUp"].sumw == [18.0, 24.0, 38.0]
    @test_throws ArgumentError merge_samples(t, ["A", "Z"])
    @test merge_samples(t, ["A", "Z"]; allow_missing=true).nominal == t["A"].nominal

    ft = collect_templates(Dict(("x", "nominal") => (edges=EDGES, sumw=[1, 1, 1], sumw2=[1, 1, 1], overflow=(2, 2)),
                                ("x", "vUp") => (edges=EDGES, sumw=[1, 1, 1], sumw2=[1, 1, 1], overflow=(4, 4))))["x"]
    @test ft.nominal.sumw == [1.0, 1.0, 3.0] && ft.variations["vUp"].sumw == [1.0, 1.0, 5.0]

    # templates straight from a Cascade.Histograms store
    st = Cascade.Histograms.HistogramStore()
    addh(st, s, v, w) = (st.hists[Cascade.Histograms.HistKey("R", s, v, "x")] = binned_hist(EDGES, w, w))
    addh(st, "A", "nominal", [10.0, 20.0, 30.0]); addh(st, "A", "jesUp", [12.0, 19.0, 33.0])
    addh(st, "B", "nominal", [5.0, 5.0, 5.0]); addh(st, "B", "jesUp", [6.0, 5.0, 5.0])
    addh(st, "C", "jesUp", [1.0, 1.0, 1.0])                         # no nominal: skipped
    st.hists[Cascade.Histograms.HistKey("R", "A", "nominal", "y")] = binned_hist(EDGES, [1.0, 1, 1], [1.0, 1, 1])
    sts = store_templates(st, "R", "x")
    @test sort(collect(keys(sts))) == ["A", "B"] && sts["A"].variations["jesUp"].sumw == [12.0, 19.0, 33.0]
    @test collect(keys(store_templates(st, "R", "x"; samples=["B"]))) == ["B"]
    nv = add_norm_variations(sts, "lumi", 1.1, 0.9, ["A"])
    @test nv["A"].variations["lumiUp"].sumw ≈ [11.0, 22.0, 33.0] && nv["A"].variations["lumiDown"].sumw2 ≈ 0.81 .* [10.0, 20.0, 30.0]
    @test !haskey(nv["B"].variations, "lumiUp") && !haskey(sts["A"].variations, "lumiUp")
    ps = present_stack(StackConfig([SampleGroup("a", "#000000", ["A", "Z"]), SampleGroup("z", "#000000", ["Y"])], ["D", "B2"]),
                       ["A", "D"])
    @test [g.label for g in ps.groups] == ["a"] && ps.groups[1].samples == ["A"] && ps.data == ["D"]
    @test present_stack(fixture_config(), ["Q"]) === nothing
end
