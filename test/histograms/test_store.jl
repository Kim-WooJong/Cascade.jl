module TestStore
using Test, Cascade.Histograms

@testset "HistogramStore merge / scale / filter" begin
    a = HistogramStore(); b = HistogramStore()
    k1 = HistKey("r", "s1", NOMINAL, "x"); k2 = HistKey("r", "s2", variation_label("jes", :up), "x")
    fill_bin!(hist!(a, k1, [0, 1, 2]), 0.5, 2.0)
    fill_bin!(hist!(b, k1, [0, 1, 2]), 1.5, 1.0)
    fill_bin!(hist!(b, k2, [0, 1, 2]), 1.5, 1.0)
    merge_store!(a, b)
    @test a[k1].sumw == [2.0, 1.0] && a[k1].sumw2 == [4.0, 1.0]
    @test a["r", "s2", "jesUp", "x"].sumw == [0.0, 1.0]
    @test store_axis(a, :sample) == ["s1", "s2"] && store_axis(a, :variation) == ["jesUp", "nominal"]
    scale_store!(a, 2.0; sample = "s1")
    @test a[k1].sumw == [4.0, 2.0] && a[k1].sumw2 == [16.0, 4.0] && a[k2].sumw == [0.0, 1.0]
    f = filter_store(a; variation = NOMINAL)
    @test length(f) == 1 && haskey(f, k1)
    @test length(filter_store(a; sample = ["s1", "s2"], variable = "x")) == 2
    @test hist_arrays(a[k1]) == ([0.0, 1.0, 2.0], [4.0, 2.0], [16.0, 4.0])
    bad = HistogramStore(); hist!(bad, k1, [0, 5])
    @test_throws ArgumentError merge_store!(a, bad)
    @test variation_label("lumi", :down) == "lumiDown"
    @test_throws ArgumentError variation_label("x", :sideways)
    @test HistKey("a", "b", "c", "d") == HistKey("a", "b", "c", "d")
    @test hash(HistKey("a", "b", "c", "d")) == hash(HistKey(String(['a']), "b", "c", "d"))
end

@testset "luminosity_scale" begin
    @test luminosity_scale(924.0, 0.1061, 1210.0, 3.8474859656064014e9) == 924.0 * 0.1061 * 1210.0 / 3.8474859656064014e9
    @test luminosity_scale(6346.0, 1.0, 1210.0, 2.0) == 6346.0 * 1210.0 / 2.0
    @test_throws ArgumentError luminosity_scale(1, 1, 1, 0)
end
end
