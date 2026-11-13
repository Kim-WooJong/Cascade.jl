module TestJagged
using Test, Cascade.IO

@testset "Jagged" begin
    j = Jagged([[1.0f0, 2.0f0], Float32[], [3.0f0]])
    @test length(j) == 3 && j.offsets == [0, 2, 2, 3]
    @test collect(j[1]) == [1.0f0, 2.0f0] && isempty(j[2]) && collect(j[3]) == [3.0f0]
    @test_throws ArgumentError Jagged([1, 2], [0, 1])
end
end
