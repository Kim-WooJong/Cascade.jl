module TestPipelineSynthetic
# End-to-end pipeline on synthetic column files: results equal a direct
# computation, caching skips unchanged steps, hooks and variations work.
using Test, Random
import Cascade
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Histograms, Cascade.Pipeline
include(joinpath(@__DIR__, "..", "selection", "synthetic_events.jl"))
using .SyntheticEvents

# Selection snippet source: the frozen genWeight-only ttbar file (the production
# analysis.toml now also carries corrections/shape/fit sections behind options).
const TTBAR = normpath(joinpath(@__DIR__, "..", "config", "fixtures", "analysis.toml"))
const TTBAR_DIR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu"))

"ttbar_emu definition with synthetic samples (format cols) and one expression variation."
function write_analysis(dir; jet_bins = "range = [30.0, 20.0, 410.0]")
    txt = read(TTBAR, String)
    i = findfirst("[data_quality]", txt)
    rest = txt[first(i):end]
    rest = replace(rest, "golden_json = \"Cert_Collisions2022_355100_362760_Golden.json\"" =>
                         "golden_json = \"" * joinpath(TTBAR_DIR, "Cert_Collisions2022_355100_362760_Golden.json") * "\"")
    rest = replace(rest, "[weights]\nmc = [\"genWeight\"]\ndata = []" =>
        "[weights]\nmc = [\"genWeight\"]\ndata = []\nvariations = [{ name = \"scale\", up = \"1.1\", down = \"0.9\" }]")
    rest = replace(rest, "name = \"jet1_pt\"\nrange = [30.0, 20.0, 410.0]" => "name = \"jet1_pt\"\n" * jet_bins)
    head = """
    [analysis]
    name = "synthetic"
    lumi_pb = 100.0
    workdir = "work"
    [merge]
    yield_variable = "njet"
    [[samples]]
    name = "sigA"
    kind = "mc"
    xsec_pb = 2.0
    branching_ratio = 0.5
    format = "cols"
    files = ["$(dir)/sigA/*.cols"]
    [[samples]]
    name = "bkgB"
    kind = "mc"
    xsec_pb = 3.0
    format = "cols"
    files = ["$(dir)/bkgB/*.cols"]
    [[samples]]
    name = "dataEG"
    kind = "data"
    stream = "EGamma"
    format = "cols"
    files = ["$(dir)/dataEG/*.cols"]
    """
    p = joinpath(dir, "analysis.toml")
    write(p, head * "\n" * rest)
    return p
end

function write_inputs(dir)
    rng = MersenneTwister(99)
    for (s, nf) in (("sigA", 3), ("bkgB", 2), ("dataEG", 2))
        for k in 1:nf
            cols = synthetic_events(rng, 3000)
            meta = s == "dataEG" ? Dict{String,Any}() : Dict{String,Any}("gen_weight_sum" => 1000.0 * k)
            write_column_file(joinpath(dir, s, "f$k.cols"), cols; meta)
        end
    end
end

summary_runs(sm) = Dict(k => v["run"] for (k, v) in sm)

@testset "pipeline end-to-end (synthetic)" begin
    mktempdir() do dir
        write_inputs(dir)
        cfgp = write_analysis(dir)
        work = joinpath(dir, "work")
        sm = run_pipeline(RunOptions(cfgp; workdir = work))
        @test all(v["run"] >= 1 for v in values(sm))
        cfg = load_analysis(cfgp)
        merged = read_store(joinpath(work, "merge", "histograms.json"))

        # direct computation for sigA: selection over files in order, scale by xsec*br*L/sum(gen)
        sel = compile_selection(cfg, :mc)
        files = sort(readdir(joinpath(dir, "sigA"); join = true))
        direct = HistogramStore()
        for f in files                                  # per-file stores merged in file order
            t, _ = run_selection(sel, ColumnFileSource(f))
            chunk = HistogramStore()
            rs = t.meta["region_stage"]
            regions = [r.name => Bool[x >= rs[r.name] for x in t["stage"]] for r in cfg.regions]
            vals = Dict{String,Any}(h.name => Vector{Float64}[t[c] for c in t.meta["hist_columns"][h.name]] for h in cfg.histograms)
            w = Vector{Float64}(t["weight"])
            fill_store!(chunk, "sigA", cfg.histograms, vals, regions,
                        [NOMINAL => w, "scaleUp" => w .* 1.1, "scaleDown" => w .* 0.9])
            merge_store!(direct, chunk)
        end
        norm = luminosity_scale(2.0, 0.5, 100.0, 1000.0 + 2000.0 + 3000.0)
        scale_store!(direct, norm)
        for k in keys(direct)
            @test merged[k] == direct[k]
        end
        @test store_axis(merged, :variation) == ["nominal", "scaleDown", "scaleUp"]
        @test !any(k.sample == "dataEG" && k.variation != NOMINAL for k in keys(merged))
        info = read(joinpath(work, "merge", "yields.tsv"), String)
        @test occursin("TOTAL_DATA", info) && occursin("TOTAL_MC", info)
        @test isfile(joinpath(work, "merge", "cutflow", "sigA.tsv"))
        @test isfile(joinpath(work, "plot", "yields.txt")) && isfile(joinpath(work, "fit", "result.json"))

        # second run: everything cached
        sm2 = run_pipeline(RunOptions(cfgp; workdir = work))
        @test all(v["run"] == 0 for v in values(sm2))

        # binning change: select/correct stay cached, histogram and downstream rerun
        write_analysis(dir; jet_bins = "edges = [30.0, 100.0, 1000.0]")
        sm3 = run_pipeline(RunOptions(cfgp; workdir = work))
        @test sm3[:skim]["run"] == 0 && sm3[:select]["run"] == 0 && sm3[:correct]["run"] == 0
        @test sm3[:histogram]["run"] == 7 && sm3[:merge]["run"] == 1
        @test read_store(joinpath(work, "merge", "histograms.json"))["emu_ge1j", "sigA", NOMINAL, "jet1_pt"].edges ==
              [30.0, 100.0, 1000.0]

        # touching one input file reruns only that chunk
        f1 = joinpath(dir, "bkgB", "f1.cols")
        c, m, o = read_column_file(f1)
        write_column_file(f1, c; order = o, meta = Dict{String,Any}("gen_weight_sum" => 1000.0))
        sm4 = run_pipeline(RunOptions(cfgp; workdir = work, steps = [:skim, :select]))
        @test sm4[:skim]["run"] == 1 && sm4[:select]["run"] == 1

        # --only with a custom correct hook (registered) and a sample subset
        register_hook!(:correct, ctx -> Dict(NOMINAL => 2 .* Vector{Float64}(ctx.table["weight"])); id = "double")
        try
            sm5 = run_pipeline(RunOptions(cfgp; workdir = work, steps = [:correct, :histogram, :merge],
                                          samples = ["sigA"]))
            @test sm5[:correct]["run"] == 3
            m5 = read_store(joinpath(work, "merge", "histograms.json"))
            k = HistKey("emu_ge1j", "sigA", NOMINAL, "njet")
            @test m5[k].sumw == 2 .* direct[k].sumw
            @test store_axis(m5, :sample) == ["sigA"]
        finally
            empty!(Cascade.Pipeline.HOOKS)
        end

        # missing upstream artifact is reported
        @test_throws ArgumentError run_pipeline(RunOptions(cfgp; workdir = joinpath(dir, "fresh"), steps = [:histogram]))
        @test main(["run", cfgp, "--workdir", joinpath(dir, "cli"), "--only", "skim"]) == 0
        @test isfile(joinpath(dir, "cli", "skim", "sigA.json"))
    end
end
end
