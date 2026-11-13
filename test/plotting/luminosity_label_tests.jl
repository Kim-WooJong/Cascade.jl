module TestLuminosityLabels
using Test
using Cascade.Config, Cascade.Plotting

@testset "Plot luminosity follows used exposure" begin
    raw = Dict{String,Any}("analysis" => Dict("lumi_pb" => 1210.0))
    cfg = parse_analysis(raw)
    @test plot_options(cfg).lumi == "1.21 fb^{-1}"
    @test plot_options(cfg; lumi_pb = 500.0).lumi == "0.5 fb^{-1}"
    raw["plot"] = Dict("lumi_label" => "custom exposure")
    custom = parse_analysis(raw)
    @test plot_options(custom).lumi == "custom exposure"
    @test plot_options(custom; lumi_pb = 500.0).lumi == "custom exposure"
end
end
