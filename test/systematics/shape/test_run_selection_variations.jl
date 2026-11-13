module TestRunSelectionVariations
# Selection over shared columns with column replacements (shape variations).
using Test, Random, TOML
using Cascade.Config, Cascade.IO, Cascade.Selection
include(joinpath(@__DIR__, "..", "..", "selection", "synthetic_events.jl"))
include(joinpath(@__DIR__, "..", "..", "pipeline", "shape_events.jl"))
using .SyntheticEvents, .ShapeEvents

const DIR = normpath(joinpath(@__DIR__, "..", "..", "..", "analyses", "shape_test"))

# isequal: histogram value columns use NaN for "not filled"
same_table(a, b) = a.order == b.order && all(isequal(a[c], b[c]) for c in a.order) && a.meta["cutflow"] == b.meta["cutflow"]

function doubled_met(cols)
    c = copy(cols)
    c["PuppiMET_pt"] = 2 .* cols["PuppiMET_pt"]
    return c
end

@testset "run_selection_variations" begin
    rng = MersenneTwister(11)
    cols = add_shape_columns!(rng, synthetic_events(rng, 3000))
    src = MemorySource(cols, 3000)
    cfg = load_analysis(joinpath(DIR, "analysis.toml"))
    sel = compile_selection(cfg, :mc)
    ref, rcf = run_selection(sel, src)

    r0 = run_selection_variations(sel, src, (raw, needed) -> Pair{String,Dict{String,Any}}[])
    @test length(r0) == 1 && first(r0[1]) == "nominal" && same_table(last(r0[1])[1], ref)
    @test last(r0[1])[2].n == rcf.n && last(r0[1])[2].sumw == rcf.sumw

    seen = Ref{Any}(nothing)
    vary = function (raw, needed)
        seen[] = needed
        @test haskey(raw, "GenJet_pt")                                  # extra inputs are read
        return ["same" => Dict{String,Any}(), "met2" => Dict{String,Any}("PuppiMET_pt" => 2 .* raw["PuppiMET_pt"])]
    end
    r1 = run_selection_variations(sel, src, vary; inputs = ["GenJet_pt"], replaces = ["PuppiMET_pt"], sample = "x")
    @test first.(r1) == ["nominal", "same", "met2"]
    @test seen[] isa Vector{Bool}                                       # MET used after the object cuts: masked read
    @test same_table(last(r1[1])[1], ref)
    t_same = last(r1[2])[1]
    @test t_same.meta["variation"] == "same" && same_table(t_same, ref)
    m2, _ = run_selection(sel, MemorySource(doubled_met(cols), 3000))
    @test same_table(last(r1[3])[1], m2)

    # replacement of a column used by an object-free leading cut: all events read
    d = TOML.parsefile(joinpath(DIR, "analysis.toml"))
    d["cuts"] = vcat([Dict("name" => "met_first", "expr" => "PuppiMET_pt > 40.0")], d["cuts"])
    sel2 = compile_selection(parse_analysis(d; dir = DIR), :mc)
    @test "PuppiMET_pt" in sel2.columns_pre
    r2 = run_selection_variations(sel2, src, function (raw, needed)
        seen[] = needed
        return ["met2" => Dict{String,Any}("PuppiMET_pt" => 2 .* raw["PuppiMET_pt"])]
    end; replaces = ["PuppiMET_pt"])
    @test seen[] === nothing
    m3, _ = run_selection(sel2, MemorySource(doubled_met(cols), 3000))
    @test same_table(last(r2[2])[1], m3)
    @test same_table(last(r2[1])[1], run_selection(sel2, src)[1])

    # a "nominal" entry replaces the nominal columns
    r3 = run_selection_variations(sel, src, (raw, needed) -> ["nominal" => Dict{String,Any}("PuppiMET_pt" => 2 .* raw["PuppiMET_pt"])])
    @test length(r3) == 1 && same_table(last(r3[1])[1], m2)
end
end
