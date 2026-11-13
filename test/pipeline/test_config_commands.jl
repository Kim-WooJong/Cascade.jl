module TestConfigCommands
using Test, Cascade, Cascade.Config, Cascade.Pipeline, Cascade.IO
@testset "Config commands and configurable source" begin
    @test parse_cli(["check","a.toml","--profile","sf"])[1]===:check
    @test parse_cli(["run","a.toml","--profile=sf"])[2].profile=="sf"
    @test parse_cli(["init","new"])[1]===:init
    mktempdir() do dir
        f=init_analysis(dir)
        @test isfile(f)
        @test_throws ArgumentError init_analysis(dir)
        io=IOBuffer();cfg=check_analysis(RunOptions(f);io)
        @test cfg.name=="my_analysis"
        @test occursin("Fit: disabled",String(take!(io)))
        col=joinpath(dir,"input.cols")
        write_column_file(col,Dict{String,Any}("customWeight"=>[1.0,-0.5,2.0]))
        src=open_source("cols",col;options=Dict("gen_weight"=>"customWeight"))
        @test gen_weight_sum(src)==2.5
    end
end
end
