@testset "nodes" begin
    @testset "Binning flows" begin
        for uniform in (true, false)
            edges = uniform ? Dict("n" => 3, "low" => 0.0, "high" => 3.0) : [0.0, 1.0, 2.0, 3.0]
            mk(flow) = make_cset(corr("b", [var("x")], binning("x", edges, [1.0, 2.0, 3.0], flow)))["b"]
            c = mk("error")
            @test evaluate(c, 0.0) == 1.0
            @test evaluate(c, 1.0) == 2.0
            @test evaluate(c, prevfloat(3.0)) == 3.0
            @test_throws CorrectionError evaluate(c, 3.0)
            @test_throws CorrectionError evaluate(c, -0.1)
            @test evaluate(c, -0.0) == 1.0                    # -0.0 is not below edge 0.0
            c = mk("clamp")
            @test evaluate(c, -5.0) == 1.0
            @test evaluate(c, 5.0) == 3.0
            c = mk(42.0)
            @test evaluate(c, -5.0) == 42.0
            @test evaluate(c, 3.0) == 42.0
            @test evaluate(c, 2.5) == 3.0
            c = mk("wrap")
            @test evaluate(c, 3.5) == 1.0
            @test evaluate(c, -0.5) == 3.0
            @test evaluate(c, 7.0) == 2.0
            c = mk(formula("x*x", ["x"]))
            @test evaluate(c, 4.0) == 16.0
        end
        c = make_cset(corr("b", [var("n", "int")], binning("n", [0.0, 2.0, 5.0], [1.0, 2.0], "clamp")))["b"]
        @test evaluate(c, 3) == 2.0
        @test evaluate(c, Int32(-4)) == 1.0
        c = make_cset(corr("b", [var("x")], binning("x", [-1.0, 0.0, "inf"], [1.0, 2.0], "error")))["b"]
        @test evaluate(c, 1e300) == 2.0
        @test_throws CorrectionError evaluate(c, Inf)
    end
    @testset "MultiBinning" begin
        mb(flow) = make_cset(corr("m", [var("x"), var("n", "int")],
            Dict("nodetype" => "multibinning", "inputs" => ["x", "n"],
                 "edges" => [Dict("n" => 3, "low" => 0.0, "high" => 3.0), [0.0, 2.0, 5.0]],
                 "content" => [1.0, 2.0, 3.0, 4.0, 5.0, 6.0], "flow" => flow)))["m"]
        c = mb("error")
        @test evaluate(c, 0.5, 1) == 1.0
        @test evaluate(c, 0.5, 3) == 2.0
        @test evaluate(c, 2.5, 4) == 6.0
        @test_throws CorrectionError evaluate(c, 2.5, 5)
        c = mb("clamp")
        @test evaluate(c, 10.0, 10) == 6.0
        c = mb(-1.0)
        @test evaluate(c, 10.0, 1) == -1.0
        @test evaluate(c, 1.5, 3) == 4.0
    end
    @testset "Category" begin
        c = make_cset(corr("c", [var("k", "int")],
                           category("k", [0 => 1.0, 5 => 2.0, -3 => 3.0, 5 => 9.0]; default = 7.0)))["c"]
        @test evaluate(c, 5) == 2.0            # first duplicate key wins
        @test evaluate(c, -3) == 3.0
        @test evaluate(c, 4) == 7.0
        c = make_cset(corr("c", [var("k", "int")], category("k", [1 => 1.0, 100000 => 2.0])))["c"]
        @test evaluate(c, 100000) == 2.0
        @test_throws CorrectionError evaluate(c, 2)
        c = make_cset(corr("c", [var("s", "string"), var("x")],
                           category("s", ["a" => 1.0, "b" => formula("x*2", ["x"])];
                                    default = binning("x", [0.0, 1.0], [5.0], "clamp"))))["c"]
        @test evaluate(c, "b", 1.5) == 3.0
        @test evaluate(c, "zzz", 1.5) == 5.0
        @test evaluate(c, SubString("ab", 1, 1), 0.0) == 1.0
    end
    @testset "Transform" begin
        c = make_cset(corr("t", [var("x")], Dict("nodetype" => "transform", "input" => "x",
            "rule" => formula("abs(x)", ["x"]), "content" => binning("x", [0.0, 1.0, 2.0], [1.0, 2.0], "error"))))["t"]
        @test evaluate(c, -1.5) == 2.0
        rule = binning("x", [-10.0, 0.0, 10.0], [-2.5, 2.5], "clamp")
        c = make_cset(corr("t", [var("n", "int"), var("x")], Dict("nodetype" => "transform", "input" => "n",
            "rule" => rule, "content" => category("n", [k => Float64(k) for k in -3:3]))))["t"]
        @test evaluate(c, 0, -1.0) == -3.0     # round half away from zero
        @test evaluate(c, 0, 1.0) == 3.0
    end
    @testset "FormulaRef" begin
        c = make_cset(corr("r", [var("x")], binning("x", [0.0, 1.0, 2.0], [
                Dict("nodetype" => "formularef", "index" => 0, "parameters" => [0.1, 0.2]),
                Dict("nodetype" => "formularef", "index" => 0, "parameters" => [1.1, -0.2])], "clamp");
            generic = [formula("[0] + [1]*x", ["x"])]))["r"]
        @test evaluate(c, 0.5) == 0.1 + 0.2 * 0.5
        @test evaluate(c, 1.5) == 1.1 + -0.2 * 1.5
    end
    @testset "CompoundCorrection" begin
        l1 = corr("l1", [var("x"), var("y")], formula("1+0.1*x-0.01*y", ["x", "y"]))
        l2 = corr("l2", [var("x")], binning("x", [-10.0, 0.0, 10.0, 100.0], [0.9, 1.1, 1.2], "clamp"))
        comp(iop, oop) = Dict("name" => "cc", "inputs" => [var("y"), var("x")], "output" => var("out"),
                              "inputs_update" => ["x"], "input_op" => iop, "output_op" => oop, "stack" => ["l1", "l2"])
        x, y = 5.0, 2.0
        s1 = 1 + 0.1 * x - 0.01 * y
        cs = make_cset(l1, l2; compound = [comp("*", "*")])
        c = compound_corrections(cs)["cc"]
        @test cs["cc"] === c
        s2 = x * s1 < 10.0 ? 1.1 : 1.2
        @test evaluate(c, y, x) == s1 * s2
        cs = make_cset(l1, l2; compound = [comp("+", "last")])
        s2 = x + s1 < 10.0 ? 1.1 : 1.2
        @test evaluate(compound_corrections(cs)["cc"], y, x) == s2
        @test_throws CorrectionError make_cset(l1; compound = [comp("*", "*")])   # missing constituent
    end
end
