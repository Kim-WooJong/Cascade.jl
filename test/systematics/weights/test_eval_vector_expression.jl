@testset "eval_vector_expression / object_expression" begin
    cols = Dict(:x => [1.0, -2.0, 3.0], :y => [0.5, 0.5, 4.0])
    res = ex -> ex isa Symbol ? get(cols, ex, nothing) : nothing
    ev(s) = eval_vector_expression(Cascade.Selection.parse_expression(s), res, 3)
    @test ev("abs(x) + 2y") == [2.0, 3.0, 11.0]
    @test ev("x < y") == [false, true, true]
    @test ev("0 < x < 2") == [true, false, false]
    @test ev("x > 0 && y > 1") == [false, false, true]
    @test ev("x > 0 || y > 1") == [true, false, true]
    @test ev("x > 0 ? x : -x") == [1.0, 2.0, 3.0]
    @test ev("max(x, y) * pi") == max.([1.0, -2.0, 3.0], [0.5, 0.5, 4.0]) .* Float64(pi)
    @test ev("1") == [1.0, 1.0, 1.0]
    @test_throws ArgumentError ev("foo(x)")
    @test_throws ArgumentError ev("z + 1")
    @test_throws ArgumentError ev("x ? 1 : 2")
    # sub-expressions resolved before evaluation
    res2 = ex -> ex == :(x + y) ? [10.0, 20.0, 30.0] : res(ex)
    @test eval_vector_expression(:(abs(x + y)), res2, 3) == [10.0, 20.0, 30.0]

    @test string(object_expression(:eta, "muons", 1)) == "muons.eta[1]"
    @test string(object_expression(:(eta + deltaEtaSC), "electrons", 2)) == "electrons.eta[2] + electrons.deltaEtaSC[2]"
    @test object_expression(:(abs(eta) < 1.5 * pi), "m", 1) == :(abs(m.eta[1]) < 1.5 * pi)
    @test object_expression(:(10 < pt < 20), "m", 3) == :(10 < m.pt[3] < 20)
end
