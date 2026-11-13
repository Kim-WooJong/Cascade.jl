@testset "binned_hist (Histograms.BinnedHist)" begin
    @test BinnedHist === Cascade.Histograms.BinnedHist            # one histogram type in Cascade
    x = binned_hist([0, 1, 2], [1, -2], [1, 4]; underflow=(0.5, 0.25), overflow=(3, 9))
    @test x isa Cascade.Histograms.BinnedHist
    @test x.sumw == [1.5, 1.0] && x.sumw2 == [1.25, 13.0]          # flow folded into first / last bin
    d = binned_hist([0, 1, 2], [1, -2], [1, 4]; underflow=(0.5, 0.25), overflow=(3, 9),
                    fold_underflow=false, fold_overflow=false)
    @test d.sumw == [1.0, -2.0] && d.sumw2 == [1.0, 4.0]           # flow dropped
    @test_throws ArgumentError binned_hist([0, 1], [1, 2], [1, 2])
    @test_throws ArgumentError binned_hist([0, 0], [1], [1])
    @test_throws ArgumentError binned_hist([0, 1], [1], [-1])
    @test_throws ArgumentError binned_hist([0, 1], [NaN], [1])
    @test_throws ArgumentError binned_hist([0, 1], [1], [1]; overflow=(1, -1))
    w = [1.0, 2.0]; y = binned_hist([0, 1, 2], w, w); w[1] = 99
    @test y.sumw == [1.0, 2.0]                                      # no aliasing

    s = hist_sum(d, d)
    @test s.sumw == [2.0, -4.0] && s.sumw2 == [2.0, 8.0] && d.sumw == [1.0, -2.0]
    k = hist_scale(d, 2)
    @test k.sumw == [2.0, -4.0] && k.sumw2 == [4.0, 16.0]
    @test_throws ArgumentError hist_sum(d, binned_hist([0, 1, 3], [1, 1], [1, 1]))
    @test_throws ArgumentError hist_scale(d, Inf)
    @test total_yield(d) == (sumw=-1.0, sumw2=5.0)

    r = to_hist1d(d)
    @test r isa Hist1D && r.sumw == d.sumw && r.overflow == (0.0, 0.0)
    @test binned_hist(r) == d
    h1 = Hist1D([0.0, 1.0, 2.0], [1.0, 2.0], [1.0, 2.0]; underflow=(1.0, 1.0), overflow=(2.0, 4.0))
    @test binned_hist(h1).sumw == [2.0, 4.0] && binned_hist(h1).sumw2 == [2.0, 6.0]
    @test binned_hist(h1; fold_underflow=false, fold_overflow=false).sumw == [1.0, 2.0]
end
