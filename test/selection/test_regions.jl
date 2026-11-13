module TestRegions
using Test
using Cascade.Config, Cascade.Selection
using Cascade.IO: Jagged
using ..SyntheticEvents: MemorySource

@testset "independent region predicates" begin
    raw = Dict{String,Any}(
        "samples" => [Dict("name" => "data", "kind" => "data", "files" => ["events.cols"])],
        "cuts" => [Dict("name" => "positive", "expr" => "x > 0"), Dict("name" => "high", "expr" => "x >= 2")],
        "regions" => [Dict("name" => "inclusive", "after" => "positive"),
                      Dict("name" => "low", "after" => "positive", "expr" => "x < 2"),
                      Dict("name" => "high", "after" => "positive", "expr" => "x >= 2")],
        "histograms" => [Dict("name" => "x", "edges" => [0., 1., 2., 4.], "values" => ["x"])])
    cfg = parse_analysis(raw)
    @test validate_analysis(cfg) === cfg
    @test cfg.regions[1].expr == "true"
    @test RegionConfig("legacy", "all").expr == "true"
    table, cf = select_events(compile_selection(cfg, :data), Dict("x" => [-1., 1., 2., 3.]), 4; sample = "data")
    masks = region_masks(table)
    @test table["entry"] == [2, 3, 4]
    @test masks["inclusive"] == [true, true, true]
    @test masks["low"] == [true, false, false]
    @test masks["high"] == [false, true, true]
    @test count(masks["low"] .& masks["high"]) == 0
    @test cf.n == [4, 3, 2] # region predicates never change sequential cutflow
    @test table.meta["regions"]["low"] == Dict("n" => 1, "sumw" => 1.0)
    @test table.meta["regions"]["high"] == Dict("n" => 2, "sumw" => 2.0)
    oldmeta = copy(table.meta); delete!(oldmeta, "region_columns")
    @test all(region_masks(EventTable(table.columns, table.order, oldmeta))["low"])
    raw["regions"][2]["expr"] = " "
    @test_throws ArgumentError validate_analysis(parse_analysis(raw))
end

@testset "event-local jagged matching before object materialization" begin
    cfg = parse_analysis(Dict{String,Any}(
        "objects" => [Dict("name" => "muons", "collection" => "Muon", "cut" => "pt > 10")],
        "cuts" => [Dict("name" => "match", "expr" => "trigger_match(0., 0., 13, 2, 0.1)"),
                   Dict("name" => "muon", "expr" => "length(muons) > 0")]))
    raw = Dict{String,Any}("Muon_pt" => Jagged([[30.], [30.]]),
        "TrigObj_eta" => Jagged([[0.], [0.]]), "TrigObj_phi" => Jagged([[0.], [0.]]),
        "TrigObj_id" => Jagged([[13], [11]]), "TrigObj_filterBits" => Jagged([[2], [2]]))
    table, cf = run_selection(compile_selection(cfg, :data), MemorySource(raw, 2))
    @test table["entry"] == [1]
    @test cf.n == [2, 1, 1]
end

@testset "region prefix guards object indexing" begin
    cfg = parse_analysis(Dict{String,Any}(
        "objects" => [Dict("name" => "jets", "collection" => "Jet", "cut" => "pt > 10")],
        "cuts" => [Dict("name" => "one", "expr" => "length(jets) >= 1")],
        "regions" => [Dict("name" => "all", "after" => "all"),
                      Dict("name" => "one", "after" => "one", "expr" => "jets.pt[1] > 20")]))
    table, _ = select_events(compile_selection(cfg, :data), Dict("Jet_pt" => Jagged([Float64[], [30.]])), 2)
    @test region_masks(table)["one"] == [false, true]
end

@testset "early regions retain their object input columns" begin
    cfg = parse_analysis(Dict{String,Any}(
        "objects" => [Dict("name" => "jets", "collection" => "Jet", "cut" => "pt > 10")],
        "cuts" => [Dict("name" => "late", "expr" => "x > 1"),
                   Dict("name" => "one", "expr" => "length(jets) >= 1")],
        "regions" => [Dict("name" => "early", "after" => "all", "expr" => "length(jets) > 0")]))
    sel = compile_selection(cfg, :data)
    raw = Dict{String,Any}("x" => [0., 2.], "Jet_pt" => Jagged([[30.], [40.]]))
    _, needed = read_selection_columns(sel, MemorySource(raw, 2))
    @test needed == [true, true]
    table, _ = run_selection(sel, MemorySource(raw, 2))
    @test region_masks(table)["early"] == [true, true]
end

@testset "kinematic helpers in compiled expressions" begin
    cfg = parse_analysis(Dict{String,Any}(
        "histograms" => [Dict("name" => "pair", "edges" => [0., 100.],
                              "values" => ["mass_massive(5, 0, 0, 12, 5, 0, pi, 12)", "pair_pt(3, 0, 4, pi / 2)"])]))
    table, _ = select_events(compile_selection(cfg, :data), Dict{String,Any}(), 1)
    @test only(table["h:pair:1"]) ≈ 26.
    @test only(table["h:pair:2"]) ≈ 5.
end
end
