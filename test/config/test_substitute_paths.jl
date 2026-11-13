module TestSubstitutePaths
using Test, Cascade.Config

@testset "substitute_paths" begin
    p = Dict("a" => "/x", "b" => "\${a}/y")
    @test substitute_paths("\${b}/z.root", p) == "/x/y/z.root"
    @test substitute_paths("~/q", p) == joinpath(homedir(), "q")
    @test_throws ArgumentError substitute_paths("\${nope}/z", p)
    withenv("CASCADE_TEST_CERT" => "/external/certification") do
        @test substitute_paths("\${ENV:CASCADE_TEST_CERT}/golden.json", p) == "/external/certification/golden.json"
        @test substitute_paths("\${mask}", Dict("mask" => "\${ENV:CASCADE_TEST_CERT}/golden.json")) == "/external/certification/golden.json"
    end
    withenv("CASCADE_TEST_CERT" => nothing) do
        @test_throws ArgumentError substitute_paths("\${ENV:CASCADE_TEST_CERT}", p)
    end
    withenv("CASCADE_TEST_CERT" => "") do
        @test_throws ArgumentError substitute_paths("\${ENV:CASCADE_TEST_CERT}", p)
    end
    @test_throws ArgumentError substitute_paths("\${a}", Dict("a" => "\${a}"))
end
end
