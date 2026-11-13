module TestValidateAnalysis
using Test, Cascade.Config

base() = Dict{String,Any}(
    "analysis" => Dict("name" => "t", "lumi_pb" => 1.0),
    "samples" => Any[Dict{String,Any}("name" => "a", "kind" => "mc", "xsec_pb" => 1.0, "files" => ["x.cols"])],
    "objects" => Any[Dict{String,Any}("name" => "jets", "collection" => "Jet", "cut" => "pt > 1")],
    "cuts" => Any[Dict{String,Any}("name" => "c1", "expr" => "length(jets) > 0")],
    "histograms" => [Dict("name" => "h", "edges" => [0, 1], "values" => ["1.0"])])

@testset "validate_analysis" begin
    @test validate_analysis(parse_analysis(base())) isa AnalysisConfig
    cfg = parse_analysis(base())
    @test [r.name for r in cfg.regions] == ["signal"] && cfg.regions[1].after == "c1"
    d = base(); push!(d["cuts"], Dict("name" => "c1", "expr" => "true"))
    @test_throws ArgumentError validate_analysis(parse_analysis(d))
    d = base(); d["regions"] = [Dict("name" => "r", "after" => "nope")]
    @test_throws ArgumentError validate_analysis(parse_analysis(d))
    d = base(); d["samples"][1]["xsec_pb"] = -1.0
    @test_throws ArgumentError validate_analysis(parse_analysis(d))
    d = base(); push!(d["objects"], Dict("name" => "x", "collection" => "X", "clean" => Dict("against" => ["later"])))
    @test_throws ArgumentError validate_analysis(parse_analysis(d))
    d = base(); d["samples"][1]["kind"] = "data"; d["samples"][1]["stream"] = "S"
    d["triggers"] = Dict("priority" => ["T"], "groups" => Dict("g" => ["HLT_x"]), "streams" => Dict("T" => ["g"]))
    @test_throws ArgumentError validate_analysis(parse_analysis(d))
end
end
