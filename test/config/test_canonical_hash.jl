module TestCanonicalHash
using Test, Cascade.Config

@testset "canonical_hash" begin
    a = Dict("x" => 1, "y" => Dict("b" => [1.5, 2], "a" => "s"))
    b = Dict("y" => Dict("a" => "s", "b" => [1.5, 2]), "x" => 1)
    @test canonical_hash(a) == canonical_hash(b)
    @test canonical_hash(a) != canonical_hash(Dict("x" => 2, "y" => a["y"]))
    @test length(canonical_hash(nothing)) == 64
    cfg = parse_analysis(Dict{String,Any}("analysis" => Dict("name" => "n"), "cuts" => [Dict("name" => "c", "expr" => "true")]))
    @test section_hash(cfg, "cuts") == section_hash(cfg, "cuts")
    @test section_hash(cfg, "cuts") != section_hash(cfg, "cuts"; extra = 1)
end
end
