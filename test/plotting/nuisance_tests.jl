@testset "nuisances" begin
    t = fixture_templates()
    ts = [t["A"], t["B"]]
    @test nuisance_shifts(ts, Nuisance("jes")) == ([3.0, 2.0, 3.0], [1.0, 1.0, 0.0])
    @test nuisance_shifts(ts, Nuisance("jes"; symmetrize=:max)) == ([3.0, 2.0, 3.0], [3.0, 2.0, 3.0])
    @test nuisance_shifts(ts, Nuisance("jes"; symmetrize=:average)) == ([2.0, 1.5, 1.5], [2.0, 1.5, 1.5])
    @test nuisance_shifts(ts, Nuisance("jes"; symmetrize=:half_difference)) == ([2.0, 1.5, 1.0], [2.0, 1.5, 1.0])
    @test nuisance_shifts(ts, Nuisance("jes"); integrate=true) == ([5.0], [0.0])
    @test nuisance_shifts(t["B"], Nuisance("jes")) == ([1.0, 0.0, 0.0], [0.0, 0.0, 0.0])
    @test nuisance_shifts(ts, Nuisance("toppt"; down=nothing)) == ([1.0, 0.0, 0.0], [1.0, 0.0, 0.0])
    @test nuisance_shifts(ts, Nuisance("scale", ["mur1", "mur2"])) == ([1.0, 1.0, 1.0], [1.0, 2.0, 0.0])
    @test nuisance_shifts(ts, Nuisance("pdf", ["pdf1", "pdf2"]; rule=:quadrature)) == ([1.0, 0.0, 0.0], [0.0, 2.0, 0.0])
    @test nuisance_shifts(ts, Nuisance("pdf", ["pdf1", "pdf2"]; rule=:quadrature, symmetrize=:max)) ==
          ([1.0, 2.0, 0.0], [1.0, 2.0, 0.0])
    @test_throws ArgumentError Nuisance("x", ["a"]; rule=:bogus)
    @test_throws ArgumentError Nuisance("x", ["a", "b"]; symmetrize=:half_difference)
    @test_throws ArgumentError Nuisance("x"; symmetrize=:bogus)

    inferred = infer_nuisances(ts)
    @test [n.name for n in inferred] == ["jes", "mur1", "mur2", "pdf1", "pdf2", "toppt"]
    @test inferred[1].variations == ["jesUp", "jesDown"] && inferred[6].variations == ["topptUp"]
    @test inferred[2].variations == ["mur1"]
    only_down = SampleTemplates("x", h([1.0, 1.0, 1.0]), Dict("bDown" => h([0.0, 1.0, 1.0])))
    @test infer_nuisances([only_down])[1].variations == ["bDown"]
    @test nuisance_shifts(only_down, infer_nuisances([only_down])[1]) == ([1.0, 0.0, 0.0], [1.0, 0.0, 0.0])
    @test_throws ArgumentError infer_nuisances([SampleTemplates("x", h([1.0, 1, 1]), Dict("Up" => h([1.0, 1, 1])))])
end
