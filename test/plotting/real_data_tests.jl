# The example readers only define functions; they are loaded unconditionally at top level.
const EXAMPLE_LIB = joinpath(@__DIR__, "..", "..", "examples", "plotting", "lib")
include(joinpath(EXAMPLE_LIB, "read_ttbar_tsv.jl"))
include(joinpath(EXAMPLE_LIB, "read_ttbar_cutflow.jl"))
include(joinpath(EXAMPLE_LIB, "load_ttbar_templates.jl"))
include(joinpath(EXAMPLE_LIB, "load_ttbar_cutflow.jl"))
include(joinpath(EXAMPLE_LIB, "ttbar_scale_factors.jl"))

@testset "prior ttbar outputs (CASCADE_REAL_DATA=1)" begin
    if get(ENV, "CASCADE_REAL_DATA", "0") != "1"
        @test_skip "set CASCADE_REAL_DATA=1 on gate"
    else
        root = get(ENV, "TTBAR_CTRL", joinpath(homedir(), "analisis", "ttbar_ctrl"))
        cfgpath = joinpath(@__DIR__, "..", "..", "examples", "plotting", "ttbar_ctrl.toml")
        cfg = TOML.parsefile(cfgpath)
        sc = stack_config(cfg)
        tpl = load_ttbar_templates(joinpath(root, "out_slim"), joinpath(root, "out_data"), cfg; variables=["njet"])["njet"]
        g = group_templates(tpl, sc)
        d = merge_data(tpl, sc)
        mc = sum(sum(x.nominal.sumw) for x in g)
        @test round(mc; digits=4) == 6434.9316                       # docs/DESIGN.md reference, >= 1 jet
        @test round(mc - sum(x.nominal.sumw[1] for x in g); digits=4) == 4235.2102
        @test sum(d.sumw) == 5905 && sum(d.sumw) - d.sumw[1] == 3836
        @test [round(sum(x.nominal.sumw); digits=1) for x in g] == [105.5, 234.9, 533.1, 5561.5]   # prior plots.log
        cf = load_ttbar_cutflow(joinpath(root, "out_cutflow"), cfg)
        gc = group_cutflow(cf, StackConfig(sc.groups, String[]); scale=ttbar_scale_factors(joinpath(root, "out_cutflow"), cfg))
        i = findfirst(==("njet_ge1"), gc.stages)
        @test isapprox(sum(gc.sumw[i, :]), mc; rtol=1e-9)
    end
end
