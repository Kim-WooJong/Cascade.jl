module TestLoadAnalysis
using Test, Cascade.Config

const TTBAR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu", "analysis.toml"))

@testset "load ttbar_emu analysis" begin
    cfg = load_analysis(TTBAR)
    @test cfg.name == "ttbar_emu"
    @test cfg.lumi_pb == 1210.0
    @test length(cfg.samples) == 13
    @test count(is_mc, cfg.samples) == 9 && count(is_data, cfg.samples) == 4
    tt = sample_by_name(cfg, "TTto2L2Nu")
    @test tt.xsec_pb * tt.branching_ratio == 924.0 * 0.1061      # reference XSEC value
    @test sample_by_name(cfg, "WZto3LNu").branching_ratio == 1.0
    @test sample_by_name(cfg, "SingleMuon").stream == "Muon"
    @test all(startswith(f, homedir()) for s in cfg.samples for f in s.files)
    @test [c.name for c in cfg.cuts] == ["lumimask", "trigger", "two_leptons", "extra_lepton_veto",
                                          "opposite_sign", "mll", "njet_ge1", "njet_ge2"]
    @test cfg.cuts[1].only === :data
    @test [r.after for r in cfg.regions] == ["njet_ge1", "njet_ge2"]
    @test [h.name for h in cfg.histograms] == ["lep_pt", "lep_eta", "jet1_pt", "jet2_pt", "jet3_pt",
                                                "jet1_eta", "mll", "njet"]
    @test cfg.histograms[2].edges == collect(range(-2.4, 2.4; length = 21))
    @test cfg.objects[end].clean_against == ["electrons", "muons"] && cfg.objects[end].sort_by == "pt"
    @test cfg.data_quality.run_min == 356309 && cfg.data_quality.run_max == 356615
    @test isfile(cfg.data_quality.golden_json)
    @test cfg.triggers.priority == ["MuonEG", "Muon", "EGamma"]
    @test cfg.weights_mc == ["genWeight"] && isempty(cfg.weights_data)
end
end
