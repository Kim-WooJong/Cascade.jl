module TestTriggerMatch
using Test, Cascade.Config, Cascade.Selection, Cascade.IO

@testset "optional trigger-object matching" begin
    match(args...) = trigger_match(args...)
    @test match(0.0, π - 0.01, 13, 2, 0.1, [0.0], [-π + 0.01], [-13], [6])
    @test !match(0.0, 0.0, 13, 2, 0.1, [0.0], [0.0], [11], [2])
    @test !match(0.0, 0.0, 13, 6, 0.1, [0.0], [0.0], [13], [2])
    @test !match(0.0, 0.0, 13, 2, 0.1, [0.1], [0.0], [13], [2])
    @test match(0.0, 0.0, 13, 0, 0.1, [0.0], [0.0], [13], [0])
    @test !match(NaN, 0.0, 13, 2, 0.1, [0.0], [0.0], [13], [2])
    @test !match(0.0, 0.0, 13, 2, 0.1, [NaN], [0.0], [13], [2])
    @test !match(0.0, 0.0, 13, 2, 0.1, Float64[], Float64[], Int[], Int[])
    @test_throws ArgumentError match(0.0, 0.0, 13, 2, 0.0, [0.0], [0.0], [13], [2])
    @test_throws ArgumentError match(0.0, 0.0, 13, -1, 0.1, [0.0], [0.0], [13], [2])
    @test_throws ArgumentError match(0.0, 0.0, 13, 2, 0.1, [0.0], Float64[], [13], [2])
    cfg = parse_analysis(Dict{String,Any}(
        "objects" => [Dict("name" => "muons", "collection" => "Muon", "cut" => "pt > 10")],
        "cuts" => [Dict("name" => "one_muon", "expr" => "length(muons) >= 1"),
                   Dict("name" => "match", "expr" => "trigger_match(muons.eta[1], muons.phi[1], 13, 2, 0.1)")]))
    sel = compile_selection(cfg, :mc)
    raw = Dict{String,Any}("Muon_pt" => Jagged([[30.0], [30.0], [30.0]]),
        "Muon_eta" => Jagged([[0.0], [0.0], [0.0]]), "Muon_phi" => Jagged([[0.0], [0.0], [0.0]]),
        "TrigObj_eta" => Jagged([[0.0], [0.0], Float64[]]),
        "TrigObj_phi" => Jagged([[0.0], [0.0], Float64[]]),
        "TrigObj_id" => Jagged([[13], [11], Int[]]), "TrigObj_filterBits" => Jagged([[2], [2], Int[]]))
    table, cf = select_events(sel, raw, 3)
    @test table["entry"] == [1]
    @test "TrigObj" in sel.collections
    @test all(c -> c in union(sel.columns_pre, sel.columns_post),
              ["TrigObj_eta", "TrigObj_phi", "TrigObj_id", "TrigObj_filterBits"])
    # Matching also works as an object-free prefix expression: it still needs
    # event-local offsets, even before selected objects are materialized.
    prefix_cfg = parse_analysis(Dict{String,Any}("cuts" => [Dict("name" => "match",
        "expr" => "trigger_match(0.0, 0.0, 13, 2, 0.1)")]))
    prefix_table, _ = select_events(compile_selection(prefix_cfg, :mc), raw, 3)
    @test prefix_table["entry"] == [1]
    @test_throws ArgumentError compile_object_expression("trigger_match(eta, phi, 13, 2, 0.1)", "Muon")
end
end
