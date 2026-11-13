module TestFillBin
using Test, Cascade.Histograms

@testset "fill_bin! flow semantics" begin
    h = BinnedHist([0.0, 1.0, 2.0])
    fill_bin!(h, -0.1, 1.0)          # underflow dropped
    fill_bin!(h, 0.0, 1.0)           # low edge inclusive
    fill_bin!(h, 1.0, 2.0)           # edge belongs to the upper bin
    fill_bin!(h, 2.0, 3.0)           # upper edge -> last bin
    fill_bin!(h, 1e9, 4.0)           # overflow -> last bin
    fill_bin!(h, NaN, 100.0)         # no value
    fill_bin!(h, 0.5f0, 0.5)         # Float32 value
    @test h.sumw == [1.5, 9.0]
    @test h.sumw2 == [1.25, 29.0]
    @test integral(h) == 10.5
    @test_throws ArgumentError BinnedHist([0.0, 1.0], [1.0, 2.0], [1.0])
end
end
