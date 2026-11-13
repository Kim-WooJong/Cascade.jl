module TestShapeVariationsConfig
# [[shape_variations]] parsing, defaults and validation.
using Test, TOML
using Cascade.Config

const DIR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "shape_test"))
const TTBAR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu", "analysis.toml"))

base() = TOML.parsefile(joinpath(DIR, "analysis.toml"))
errors(d) = validate_shape_variations(parse_analysis(d; dir = DIR))

@testset "shape_variations config" begin
    cfg = load_analysis(joinpath(DIR, "analysis.toml"))
    vs = shape_variations(cfg)
    @test [v.name for v in vs] == ["JES_Total", "JER", "MuScale"]
    @test [v.kind for v in vs] == [:jes, :jer, :scale]
    jes, jer, mu = vs
    @test jes.collection == "Jet" && jes.fields == ["pt", "mass"] && jes.met == "PuppiMET" && jes.met_min_pt == 15.0
    @test jes.params["corrections"] == joinpath(DIR, "test_jerc.json") && jes.params["source"] == "Test_JES_Total"
    @test jer.params["nominal"] === false && jer.params["match_dr"] == 0.2 && jer.params["match_nsigma"] == 3.0
    @test jer.params["rho"] == "Rho_fixedGridRhoFastjetAll" && jer.params["event"] == "event"
    @test jer.params["genjet"] == "GenJet" && jer.params["genjet_index"] == "genJetIdx" && jer.params["smear"] == "JERSmear"
    @test mu.fields == ["pt"] && mu.samples == ["sigA"] && mu.params["up"] == "abs(eta) < 1.2 ? 1.01 : 1.02"
    @test isempty(validate_shape_variations(cfg))
    @test isempty(shape_variations(load_analysis(TTBAR)))

    d = base(); d["shape_variations"][1]["kind"] = "xyz"
    @test_throws ArgumentError shape_variations(parse_analysis(d; dir = DIR))
    @test any(occursin("kind must be", e) for e in errors(d))
    d = base(); d["shape_variations"][1]["typo"] = 1
    @test any(occursin("unknown key 'typo'", e) for e in errors(d))
    d = base(); d["shape_variations"][2]["name"] = "JES_Total"
    @test any(occursin("duplicate shape variation", e) for e in errors(d))
    d = base(); d["shape_variations"][1]["name"] = "bad-name"
    @test any(occursin("must match", e) for e in errors(d))
    d = base(); d["weights"]["variations"] = [Dict("name" => "MuScale", "up" => "1.1", "down" => "0.9")]
    @test any(occursin("also used by a weight variation", e) for e in errors(d))
    d = base(); d["shape_variations"][3]["samples"] = ["dataEG", "nope"]
    es = errors(d)
    @test any(occursin("'dataEG' is not MC", e) for e in es) && any(occursin("unknown sample 'nope'", e) for e in es)
    d = base(); d["shape_variations"][1]["corrections"] = "missing.json"
    @test any(occursin("corrections not found", e) for e in errors(d))
    d = base(); delete!(d["shape_variations"][1], "source")
    @test any(occursin("'source' is required", e) for e in errors(d))
    d = base(); d["shape_variations"][2]["nominal"] = true
    push!(d["shape_variations"], merge(d["shape_variations"][2], Dict("name" => "JER2")))
    @test any(occursin("more than one jer variation with nominal", e) for e in errors(d))
    d = base(); d["shape_variations"][2]["fields"] = ["mass"]
    @test any(occursin("fields must include pt", e) for e in errors(d))
    d = base(); d["paths"]["jme"] = DIR; d["shape_variations"][1]["corrections"] = "\${jme}/test_jerc.json"
    @test shape_variations(parse_analysis(d; dir = "/"))[1].params["corrections"] == joinpath(DIR, "test_jerc.json")
    d = base(); d["shape_variations"][1]["kind"] = "xyz"
    @test_throws ArgumentError validate_analysis(parse_analysis(d; dir = DIR))
end
end
