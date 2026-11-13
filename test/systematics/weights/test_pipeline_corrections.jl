# End-to-end: [hooks] correct = Cascade.Systematics.apply_corrections on synthetic
# column-file samples; weights equal an independent per-event computation.
using Random
using Cascade.Histograms, Cascade.Pipeline
include(joinpath(@__DIR__, "..", "..", "selection", "synthetic_events.jl"))
using .SyntheticEvents

# Frozen genWeight-only ttbar file (production analysis.toml carries all sections).
const BASELINE_TOML = normpath(joinpath(@__DIR__, "..", "..", "config", "fixtures", "analysis.toml"))

function write_sf_analysis(dir, setpath; trig_up = 1.02)
    txt = read(BASELINE_TOML, String)
    rest = txt[first(findfirst("[data_quality]", txt)):end]
    rest = replace(rest, "golden_json = \"Cert_Collisions2022_355100_362760_Golden.json\"" =>
        "golden_json = \"" * joinpath(@__DIR__, "..", "..", "..", "analyses", "ttbar_emu", "Cert_Collisions2022_355100_362760_Golden.json") * "\"")
    rest = replace(rest, "[variables]\n" => """
        [variables]
        mu1_pt = "muons.pt[1]"
        mu1_eta = "muons.eta[1]"
        e1_pt = "electrons.pt[1]"
        """)
    head = """
    [analysis]
    name = "synthetic_sf"
    lumi_pb = 100.0
    workdir = "work"
    [merge]
    yield_variable = "njet"
    [output]
    columns = ["mu1_pt", "mu1_eta", "e1_pt"]
    [[samples]]
    name = "sigA"
    kind = "mc"
    xsec_pb = 2.0
    format = "cols"
    files = ["$(dir)/sigA/*.cols"]
    [[samples]]
    name = "dataEG"
    kind = "data"
    stream = "EGamma"
    format = "cols"
    files = ["$(dir)/dataEG/*.cols"]
    """
    tail = """
    [hooks]
    correct = "Cascade.Systematics.apply_corrections"
    [corrections.sets]
    fx = "$(setpath)"
    [[corrections.object_sf]]
    name = "lep"
    set = "fx"
    correction = "lep_sf"
    object = "muons"
    indices = [1]
    inputs = { eta = "eta", pt = "pt" }
    systematic = "syst"
    nominal = "nom"
    up = "up"
    down = "down"
    [[corrections.object_sf]]
    name = "ewp"
    set = "fx"
    correction = "wp_sf"
    object = "electrons"
    indices = [1]
    when = "pt < 75.0"
    inputs = { year = "Y1", WorkingPoint = "A", pt = "pt" }
    systematic = "ValType"
    nominal = "sf"
    up = "sfup"
    down = "sfdown"
    [[corrections.object_sf]]
    name = "ewp"
    set = "fx"
    correction = "wp_sf"
    object = "electrons"
    indices = [1]
    when = "pt >= 75.0"
    inputs = { year = "Y1", WorkingPoint = "B", pt = "pt" }
    systematic = "ValType"
    nominal = "sf"
    up = "sfup"
    down = "sfdown"
    [[corrections.event_weight]]
    name = "pu"
    set = "fx"
    correction = "pu"
    inputs = { ntrue = "Pileup_nTrueInt" }
    systematic = "which"
    nominal = "nominal"
    up = "up"
    down = "down"
    [[corrections.flat]]
    name = "trig"
    up = $(trig_up)
    down = 0.97
    """
    p = joinpath(dir, "analysis.toml")
    write(p, head * "\n" * rest * "\n" * tail)
    return p
end

function write_sf_inputs(dir)
    rng = MersenneTwister(7)
    for (s, nf) in (("sigA", 2), ("dataEG", 1)), k in 1:nf
        cols = synthetic_events(rng, 3000)
        cols["Pileup_nTrueInt"] = Float32[round(80 * rand(rng); digits = 2) for _ in 1:3000]
        meta = s == "dataEG" ? Dict{String,Any}() : Dict{String,Any}("gen_weight_sum" => 1000.0 * k)
        write_column_file(joinpath(dir, s, "f$k.cols"), cols; meta)
    end
end

@testset "pipeline with [corrections] (synthetic)" begin
    mktempdir() do dir
        setpath = write_fixture_set(joinpath(dir, "fx.json"))
        write_sf_inputs(dir)
        cfgp = write_sf_analysis(dir, setpath)
        work = joinpath(dir, "work")
        steps = [:skim, :select, :correct, :histogram, :merge]
        sm = run_pipeline(RunOptions(cfgp; workdir = work, steps))
        @test sm[:correct]["run"] == 3
        cfg = load_analysis(cfgp)
        sel = compile_selection(cfg, :mc)
        raw = read_store(joinpath(work, "merge", "histograms_raw.json"))
        labels = ["nominal", "ewpDown", "ewpUp", "lepDown", "lepUp", "puDown", "puUp", "trigDown", "trigUp"]
        sums = Dict(l => 0.0 for l in labels)
        nrow = 0
        skim = JSON3.read(read(joinpath(work, "skim", "sigA.json"), String))
        for e in skim[:files]
            path = String(e[:path])
            t, _ = run_selection(sel, ColumnFileSource(path))
            pile = read_column_file(path)[1]["Pileup_nTrueInt"]
            n = nrows(t)
            nrow += n
            lep(s) = [fx_lep(t["v:mu1_eta"][i], t["v:mu1_pt"][i], s) for i in 1:n]
            ewp(s) = [t["v:e1_pt"][i] < 75 ? fx_wp("A", t["v:e1_pt"][i], s) : fx_wp("B", t["v:e1_pt"][i], s) for i in 1:n]
            pu(s) = [fx_pu(Float64(pile[k]), s) for k in t["entry"]]
            w = t["weight"]
            exp = Dict("nominal" => w .* lep("nom") .* ewp("sf") .* pu("nominal") .* 1.0,
                       "lepUp" => w .* lep("up") .* ewp("sf") .* pu("nominal") .* 1.0,
                       "lepDown" => w .* lep("down") .* ewp("sf") .* pu("nominal") .* 1.0,
                       "ewpUp" => w .* lep("nom") .* ewp("sfup") .* pu("nominal") .* 1.0,
                       "ewpDown" => w .* lep("nom") .* ewp("sfdown") .* pu("nominal") .* 1.0,
                       "puUp" => w .* lep("nom") .* ewp("sf") .* pu("up") .* 1.0,
                       "puDown" => w .* lep("nom") .* ewp("sf") .* pu("down") .* 1.0,
                       "trigUp" => w .* lep("nom") .* ewp("sf") .* pu("nominal") .* 1.02,
                       "trigDown" => w .* lep("nom") .* ewp("sf") .* pu("nominal") .* 0.97)
            got, _, order = read_column_file(joinpath(work, "correct", "sigA", String(e[:chunk]) * ".cols"))
            @test sort(order) == sort(labels)
            for l in labels
                @test got[l] == exp[l]
                stage = t["stage"]; rs = t.meta["region_stage"]["emu_ge1j"]
                sums[l] += sum(got[l][stage .>= rs])
            end
        end
        @test nrow > 20
        for l in labels
            @test isapprox(integral(raw["emu_ge1j", "sigA", l, "njet"]), sums[l]; rtol = 1e-12)
        end
        @test sums["lepUp"] != sums["nominal"] && sums["puDown"] != sums["nominal"]
        @test !any(k.sample == "dataEG" && k.variation != NOMINAL for k in keys(raw))

        # cached; a [corrections] change reruns correct (and downstream), not select
        sm2 = run_pipeline(RunOptions(cfgp; workdir = work, steps))
        @test sm2[:correct]["run"] == 0 && sm2[:histogram]["run"] == 0
        write_sf_analysis(dir, setpath; trig_up = 1.05)
        sm3 = run_pipeline(RunOptions(cfgp; workdir = work, steps))
        @test sm3[:select]["run"] == 0 && sm3[:correct]["run"] == 3 && sm3[:merge]["run"] == 1
        raw3 = read_store(joinpath(work, "merge", "histograms_raw.json"))
        @test isapprox(integral(raw3["emu_ge1j", "sigA", "trigUp", "njet"]), sums["nominal"] * 1.05; rtol = 1e-12)
    end
end
