@testset "stack comparison" begin
    t = fixture_templates()
    c = fixture_config()
    g = group_templates(t, c)
    b = uncertainty_band(g; nuisances=[Nuisance("jes")])
    d = merge_data(t, c)
    cmp = stack_comparison(d, g, [x.color for x in c.groups], b)
    @test cmp.prediction == [15.0, 25.0, 35.0]
    @test cmp.ratio ≈ [16 / 15, 24 / 25, 40 / 35]
    @test cmp.prediction_errors.high == b.high && cmp.prediction_errors.low == b.low
    @test cmp.ratio_prediction_errors.high ≈ b.high ./ b.prediction
    @test cmp.data_errors.low ≈ first(poisson_errors(d.sumw))
    @test [x.label for x in cmp.components] == ["Bkg B", "t#bar{t}"]
    @test cmp.uncertainty_label == "Syst. unc." || cmp.uncertainty_label == "Stat. #oplus syst. unc."
    s2 = stack_comparison(d, g, ["#000000", "#FFFFFF"], b; data_errors=:sumw2)
    @test s2.data_errors.high ≈ sqrt.(d.sumw2)

    neg = SampleTemplates("neg", BinnedHist(EDGES, [-1.0, 2.0, 0.0], [1.0, 1.0, 0.0]))
    cn = stack_comparison(d, [neg], ["#000000"], uncertainty_band([neg]; nuisances=Nuisance[]))
    @test cn.components[1].hist.sumw == [0.0, 2.0, 0.0]
    @test_throws ArgumentError stack_comparison(d, g, ["#000000"], b)
    @test_throws ArgumentError stack_comparison(binned_hist(EDGES, [1.5, 1, 1], [1, 1, 1]), g, ["#000000", "#000000"], b)

    @test auto_ylimits([[1.0, 10.0]], 10.0) == (0.0, 10 / 0.6)
    lo, hi = auto_ylimits([[1.0, 10.0]], 10.0; logy=true)
    @test lo == 0.5 && log10(hi) ≈ log10(0.5) + (1 - log10(0.5)) / 0.6
    @test auto_ylimits([[1.0e-9, 10.0]], 10.0; logy=true)[1] ≈ 1e-5
    @test auto_ylimits([[1.0]], 10.0; logy=true, ymin=0.1)[1] == 0.1
    lc = auto_ylimits(cmp)
    @test lc[1] == 0 && lc[2] ≈ max(maximum(cmp.prediction .+ b.high), maximum(d.sumw .+ cmp.data_errors.high)) / 0.6
    spec = cms_panel_spec("m (GeV)"; lumi="1.21 fb^{-1}", logy=true, bin_labels=["a", "b", "c"])
    @test spec.style == :CMS && spec.logy && spec.cms_label.lumi == "1.21 fb^{-1}" && spec.ratio_limits == (0.5, 1.5)
end
