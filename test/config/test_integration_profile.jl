module TestIntegrationProfile
using Test, Cascade, Cascade.Config
@testset "opt-in combined technical ttbar profile has no default side effects" begin
    path=normpath(joinpath(@__DIR__,"../../analyses/ttbar_emu/analysis.toml"))
    combined=load_analysis(path;profile="integration_small")
    candidate=load_analysis(path;profile="jer_candidate")
    theory=load_analysis(path;profile="theory_example")
    @test combined.raw["theory_weights"]==theory.raw["theory_weights"]
    @test [t["name"] for t in combined.raw["theory_weights"]]==["scale","ISR","FSR"]
    @test all(t["samples"]==["TTto2L2Nu"] for t in combined.raw["theory_weights"])
    for k in union(keys(candidate.raw),keys(combined.raw))
        k in ("analysis","theory_weights") && continue
        @test get(candidate.raw,k,nothing)==get(combined.raw,k,nothing)
    end
    @test combined.raw["fit"]==candidate.raw["fit"]
    @test only(filter(t->t["kind"]=="jer",combined.raw["shape_variations"]))["nominal"]===true
    @test combined.lumi_pb==1210.
    @test length(combined.samples)==13
    @test [s.name for s in combined.samples]==["TTto2L2Nu","TWminusto2L2Nu","TbarWplusto2L2Nu","WWto2L2Nu","WZto3LNu","WZto2L2Q","DYto2L_MLL50","DYto2L_MLL10to50","TTtoLNu2Q","MuonEG","SingleMuon","Muon","EGamma"]
    for p in ("baseline","sf","phase2","jer_candidate")
        @test !haskey(load_analysis(path;profile=p).raw,"theory_weights")
    end
    @test !haskey(load_analysis(path).raw,"theory_weights")
    @test !haskey(load_analysis(path).raw,"corrections")
end
end
