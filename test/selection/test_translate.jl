module TestTranslate
using Test, Cascade.Selection

tr(s; collection = nothing, variables = Dict("v" => "a + 1", "c1" => "c2", "c2" => "c1")) =
    translate_expression(parse_expression(s), ExpressionUsage(); objects = Dict("jets" => "Jet"),
                         variables, builtins = Set(["trigger"]), collection)

@testset "translate_expression" begin
    u = ExpressionUsage()
    ex = translate_expression(parse_expression("length(jets) >= 2 && jets.pt[2] > 30.0 && trigger && v > 0"), u;
                              objects = Dict("jets" => "Jet"), variables = Dict("v" => "genWeight"),
                              builtins = Set(["trigger"]))
    @test u.columns == Set(["Jet_pt", "genWeight"]) && u.objects == Set(["jets"]) && u.builtins == Set(["trigger"])
    @test u.collections == Set(["Jet"])
    @test occursin("ctx.objs.jets", string(ex)) && occursin("ctx.cols.Jet_pt", string(ex))
    uo = ExpressionUsage()
    translate_expression(parse_expression("pt > 30.0 && (jetId & 2) != 0 && 1.0 < abs(eta) < 2.0"), uo;
                         objects = Dict{String,String}(), variables = Dict{String,String}(), builtins = Set{String}(),
                         collection = "Jet")
    @test uo.columns == Set(["Jet_pt", "Jet_jetId", "Jet_eta"])
    @test_throws ArgumentError tr("c1 > 0")                     # cyclic variables
    @test_throws ArgumentError tr("jets > 0")                   # object used as value
    @test_throws ArgumentError tr("run(1)")                     # function not allowed
    @test_throws ArgumentError tr("jets.pt > 0")                # missing index
    @test_throws ArgumentError tr("muons.pt[1] > 0")            # unknown object
    @test_throws ArgumentError tr("x = 1")
    @test_throws ArgumentError tr("a; b")
    @test_throws ArgumentError tr("pt[1] > 0"; collection = "Jet")
    @test_throws ArgumentError tr("\"s\" == x")
end

@testset "compile_kernel" begin
    f = compile_kernel([:ctx, :i], tr("v > 2"))
    ctx = KernelContext((a = [1.0, 5.0],), NamedTuple(), NamedTuple())
    @test Base.invokelatest(f, ctx, 1) == false
    @test Base.invokelatest(f, ctx, 2) == true
end
end
