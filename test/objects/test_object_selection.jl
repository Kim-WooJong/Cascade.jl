module TestObjectSelection
using Test, Cascade.Objects

@testset "select / isolate / sort" begin
    pt = Float32[50, 5, 40, 60, 45]
    buf = Int[99]
    select_objects!(j -> pt[j] > 10, buf, 1, 5)          # flat indices 2:5
    @test buf == [3, 4, 5]
    eta = Float32[0, 0, 1, 0.1, 3]; phi = zeros(Float32, 5)
    @test isolated_from(eta[3], phi[3], eta, phi, [1], 0.4)
    @test !isolated_from(eta[4], phi[4], eta, phi, [1], 0.4)
    @test isolated_from(eta[4], phi[4], eta, phi, Int[], 0.4)
    sort_objects!(buf, pt)
    @test buf == [4, 5, 3]
    tie = Float32[30, 30, 31]
    b2 = [1, 2, 3]
    sort_objects!(b2, tie)
    @test b2 == [3, 1, 2]                                 # stable for ties
    @test b2 == sort([1, 2, 3]; by = k -> tie[k], rev = true)
end
end
