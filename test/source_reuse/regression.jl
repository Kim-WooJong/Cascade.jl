using Test, Cascade
for area in ("io", "systematics", "pipeline", "reduced", "streaming")
    @testset "$area" begin
        include(joinpath(@__DIR__, "..", area, "runtests.jl"))
    end
end
