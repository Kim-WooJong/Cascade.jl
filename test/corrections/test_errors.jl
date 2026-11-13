@testset "errors" begin
    c = make_cset(corr("e", [var("pt"), var("syst", "string")],
                       binning("pt", [0.0, 20.0, 40.0, "inf"], [category("syst", ["blah" => 1.1]), 1.3, 1.0],
                               "error")))["e"]
    @test evaluate(c, 12.0, "blah") == 1.1
    @test evaluate(c, 1000.0, "blah") == 1.0
    @test_throws CorrectionError evaluate(c, 0, 1.2, 35.0, 0.01)    # too many inputs
    @test_throws CorrectionError evaluate(c, 1.2)                   # not enough inputs
    @test_throws CorrectionError evaluate(c, "asdf", "blah")        # wrong type
    @test_throws CorrectionError evaluate(c, 1.0, 2.0)              # real for string input
    @test_throws CorrectionError evaluate(c, -1.0, "blah")          # underflow
    @test_throws CorrectionError evaluate(c, 5.0, "missing")        # missing category key
    ci = make_cset(corr("i", [var("k", "int")], category("k", [1 => 1.0])))["i"]
    @test_throws CorrectionError evaluate(ci, 1.0)                  # real for int input
    # load-time errors
    @test_throws CorrectionError parse_correctionset("{")
    @test_throws CorrectionError parse_correctionset("{}")
    @test_throws CorrectionError parse_correctionset("""{"schema_version": "blah"}""")
    @test_throws CorrectionError parse_correctionset("""{"schema_version": 1, "corrections": []}""")
    @test_throws CorrectionError parse_correctionset("""{"schema_version": 3, "corrections": []}""")
    @test parse_correctionset("""{"schema_version": 2, "description": "something", "corrections": []}""").description == "something"
    @test_throws CorrectionError make_cset(corr("x", [var("x")], binning("x", [0.0, 1.0], [1.0, 2.0], "clamp")))
    @test_throws CorrectionError make_cset(corr("x", [var("x")], binning("x", [1.0, 0.0], [1.0], "clamp")))
    @test_throws CorrectionError make_cset(corr("x", [var("x")], binning("y", [0.0, 1.0], [1.0], "clamp")))
    @test_throws CorrectionError make_cset(corr("x", [var("s", "string")], binning("s", [0.0, 1.0], [1.0], "clamp")))
    @test_throws CorrectionError make_cset(corr("x", [var("k", "int")], category("k", ["a" => 1.0])))
    @test_throws CorrectionError make_cset(corr("x", [var("k", "int")], formula("x", ["k"])))
    @test_throws CorrectionError make_cset(corr("x", [var("x")], Dict("nodetype" => "nope")))
    @test_throws CorrectionError make_cset(corr("x", [var("x")], "text"))
    @test_throws CorrectionError make_cset(corr("x", [], 1.0), corr("x", [], 2.0))   # duplicate name
end
