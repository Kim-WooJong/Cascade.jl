@testset "uncertainty band" begin
    t = fixture_templates()
    ts = [t["B"], t["A"]]
    ns = [Nuisance("jes"), Nuisance("scale", ["mur1", "mur2"])]
    b = uncertainty_band(ts; nuisances=ns)
    @test b.prediction == [15.0, 25.0, 35.0]
    @test b.stat ≈ sqrt.([15.0, 25.0, 35.0])
    @test b.syst_high ≈ sqrt.([9.0 + 1, 4 + 1, 9 + 1])
    @test b.syst_low ≈ sqrt.([1.0 + 1, 1 + 4, 0 + 0])
    @test b.high ≈ sqrt.([15.0 + 10, 25 + 5, 35 + 10])
    @test b.low ≈ sqrt.([15.0 + 2, 25 + 5, 35 + 0])
    @test b.nuisances == ["jes", "scale"] && b.label == "Stat. #oplus syst. unc."
    @test uncertainty_band(ts; nuisances=ns, stat=false).high ≈ b.syst_high
    s = uncertainty_band(ts; nuisances=ns, syst=false)
    @test s.high ≈ s.stat && s.label == "Stat. unc." && isempty(s.nuisances)
    @test uncertainty_band(ts; nuisances=ns, symmetrize=:max).low ≈ uncertainty_band(ts; nuisances=ns, symmetrize=:max).high
    @test length(uncertainty_band(ts).nuisances) == 6           # inferred from variation names
end
