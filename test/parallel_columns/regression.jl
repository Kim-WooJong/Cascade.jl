using Test, Cascade
@testset "bounded column reader relevant regressions" begin
    for area in ("config","io","selection")
        @testset "$area" begin
            include(joinpath(@__DIR__,"..",area,"runtests.jl"))
        end
    end
    @testset "source reuse guards" begin
        include(joinpath(@__DIR__,"../source_reuse/test_source_reuse.jl"))
    end
    @testset "reduced source guards" begin
        include(joinpath(@__DIR__,"../reduced/fixtures.jl"))
        include(joinpath(@__DIR__,"../reduced/test_lazy_correction.jl"))
    end
end
