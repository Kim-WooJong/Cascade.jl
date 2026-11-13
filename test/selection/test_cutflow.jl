module TestCutflow
using Test, Cascade.Selection

@testset "Cutflow" begin
    cf = Cutflow(["all", "a", "b"])
    record!(cf, 0, 2.0); record!(cf, 2, -1.0); record!(cf, 1, 0.5)
    @test cf.n == [3, 2, 1] && cf.sumw == [1.5, -0.5, -1.0] && cf.sumw2 == [5.25, 1.25, 1.0]
    cf2 = cutflow_from_dict(cutflow_dict(cf))
    @test cf2.n == cf.n && cf2.sumw == cf.sumw && cf2.names == cf.names
    merge_cutflow!(cf2, cf)
    @test cf2.n == 2 .* cf.n
    @test_throws ArgumentError merge_cutflow!(cf2, Cutflow(["all"]))
end
end
