module TestCLI
using Test, Cascade.Pipeline

@testset "plan_steps / parse_cli" begin
    @test plan_steps() == STEPS
    @test plan_steps(; steps = "merge,select") == [:select, :merge]
    @test plan_steps(; from = "fit") == [:fit, :plot]
    @test plan_steps(; only = "plot") == [:plot]
    @test_throws ArgumentError plan_steps(; steps = "a", only = "plot")
    @test_throws ArgumentError plan_steps(; only = "nope")
    cmd, o = parse_cli(["run", "a.toml", "--steps", "histogram,merge", "--samples=x,y", "--force", "--max-files", "3"])
    @test cmd === :run && o.config == "a.toml" && o.steps == [:histogram, :merge] && o.samples == ["x", "y"]
    @test o.force && o.max_files == 3
    @test parse_cli(["run", "a.toml", "--from", "merge"])[2].steps == [:merge, :systematics, :fit, :plot]
    @test parse_cli(["--help"])[1] === :help
    @test_throws ArgumentError parse_cli(["run"])
    @test_throws ArgumentError parse_cli(["run", "a.toml", "--bogus", "1"])
    @test_throws ArgumentError parse_cli(["frobnicate"])
    @test main(["run"]) == 2
    @test chunk_id("/a/b.root") == chunk_id("/a/b.root") && length(chunk_id("/x")) == 16
end
end
