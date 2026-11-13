module TestFitPlot
# Default fit and plot hooks end-to-end on synthetic column files: [fit] builds the
# model from the merged templates, fit/result.json + workspace.json are consistent,
# the plot hook writes prefit/postfit/impact plots and tables, caching works.
using Test, Random, JSON3
import Cascade
using Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline
import Cascade.Fit, Cascade.Plotting
include(joinpath(@__DIR__, "..", "selection", "synthetic_events.jl"))
using .SyntheticEvents

# Selection snippet source: the frozen genWeight-only ttbar file (the production
# analysis.toml now also carries corrections/shape/fit sections behind options).
const TTBAR = normpath(joinpath(@__DIR__, "..", "config", "fixtures", "analysis.toml"))
const TTBAR_DIR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu"))

const FIT_PLOT = """
[fit]
poi = "mu_sig"
signal = ["signal"]
poi_bounds = [0.0, 100.0]
channels = [{ region = "emu_ge1j", variable = "njet" }]
upper_limit = false
significance = true

[[fit.normsys]]
name = "lumi"
size = 0.014
samples = ["all"]

[[fit.normsys]]
name = "xsec_background"
size = 0.1
samples = ["background"]
placeholder = true

[plot]
formats = ["png"]
logy = ["njet"]
labels = { signal = "Signal", background = "Background" }
region_labels = { emu_ge1j = "e#mu, #geq1 jet" }
"""

function write_analysis(dir; plot_extra = "")
    txt = read(TTBAR, String)
    rest = txt[first(findfirst("[data_quality]", txt)):end]
    rest = replace(rest, "golden_json = \"Cert_Collisions2022_355100_362760_Golden.json\"" =>
                         "golden_json = \"" * joinpath(TTBAR_DIR, "Cert_Collisions2022_355100_362760_Golden.json") * "\"")
    rest = replace(rest, "[weights]\nmc = [\"genWeight\"]\ndata = []" =>
        "[weights]\nmc = [\"genWeight\"]\ndata = []\nvariations = [{ name = \"scale\", up = \"1.1\", down = \"0.9\" }]")
    # Synthetic lumisections are not certified collision data.
    rest = replace(rest, "expr = \"lumimask\"" => "expr = \"true\"",
                         "expr = \"trigger\"" => "expr = \"true\"")
    head = """
    [analysis]
    name = "synthetic_fit"
    lumi_pb = 800.0
    workdir = "work"
    [merge]
    yield_variable = "njet"
    [[samples]]
    name = "sigA"
    kind = "mc"
    group = "signal"
    xsec_pb = 2.0
    branching_ratio = 0.5
    format = "cols"
    files = ["$(dir)/sigA/*.cols"]
    [[samples]]
    name = "bkgB"
    kind = "mc"
    group = "background"
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
    write(p, head * "\n" * rest * "\n" * FIT_PLOT * plot_extra)
    return p
end

function write_inputs(dir)
    rng = MersenneTwister(7)
    for (s, nf) in (("sigA", 2), ("bkgB", 2), ("dataEG", 2))
        for k in 1:nf
            # Share kinematics so every observed bin has background support under mu=0.
            cols = synthetic_events(MersenneTwister(7 + k), 3000)
            s == "dataEG" || (cols["genWeight"] = ones(Float32, 3000))
            meta = s == "dataEG" ? Dict{String,Any}() : Dict{String,Any}("gen_weight_sum" => 3000.0)
            write_column_file(joinpath(dir, s, "f$k.cols"), cols; meta)
        end
    end
end

plain(x::JSON3.Object) = Dict{String,Any}(String(k) => plain(v) for (k, v) in pairs(x))
plain(x::JSON3.Array) = Any[plain(v) for v in x]
plain(x) = x

@testset "default fit and plot hooks (synthetic)" begin
    mktempdir() do dir
        write_inputs(dir)
        cfgp = write_analysis(dir)
        work = joinpath(dir, "work")
        sm = run_pipeline(RunOptions(cfgp; workdir = work))
        @test sm[:fit]["run"] == 1 && sm[:plot]["run"] == 1
        rep = plain(JSON3.read(read(joinpath(work, "fit", "result.json"), String)))
        @test rep["status"] == "ok" && rep["converged"] && rep["poi"] == "mu_sig"
        mu = rep["poi_value"]
        @test 0 < mu < 100 && rep["poi_error"] > 0
        lo, hi = rep["poi_interval"]
        @test lo < mu < hi
        @test only(rep["channels"])["histosys"] == ["scale"]
        @test haskey(rep, "significance") && !haskey(rep, "upper_limit")
        @test Set(x["name"] for x in rep["impacts"]) ==
              Set(p["name"] for p in rep["parameters"] if p["floating"] && p["name"] != rep["poi"])
        @test isfile(joinpath(work, "fit", "result.txt")) && occursin("PLACEHOLDER", read(joinpath(work, "fit", "result.txt"), String))

        # the exported workspace is the fitted model; it matches the merged templates
        m = Fit.HistModel(Fit.load_workspace(joinpath(work, "fit", "workspace.json")))
        r = Fit.fit(m, Fit.observed_data(m))
        @test r.parameters[m.poi] ≈ mu rtol = 1e-6
        merged = read_store(joinpath(work, "merge", "histograms.json"))
        sig = merged["emu_ge1j", "sigA", NOMINAL, "njet"].sumw
        dat = merged["emu_ge1j", "dataEG", NOMINAL, "njet"].sumw
        @test only(filter(s -> s.name == "signal", m.samples)).nominal == sig
        @test m.observations == dat
        c = only(rep["counting"])
        @test c["mu"] ≈ (sum(dat) - sum(merged["emu_ge1j", "bkgB", NOMINAL, "njet"].sumw)) / sum(sig)

        files = String.(JSON3.read(read(joinpath(work, "plot", "index.json"), String))[:files])
        @test all(isfile, files)
        for t in ("yields_emu_ge1j", "uncertainties_emu_ge1j", "cutflow", "postfit_yields_emu_ge1j_njet")
            @test joinpath(work, "plot", "tables", t * ".txt") in files
        end
        yt = read(joinpath(work, "plot", "tables", "yields_emu_ge1j.txt"), String)
        @test occursin("Signal", yt) && occursin("Background", yt) && occursin("Syst.", yt)   # lumi/xsec/scale in band
        ut = read(joinpath(work, "plot", "tables", "uncertainties_emu_ge1j.txt"), String)
        @test occursin("xsec_background", ut) && occursin("scale", ut)
        @test isfile(joinpath(work, "plot", "yields.txt"))
        if Plotting.ROOTPlots.root_available()
            for p in ("prefit/emu_ge1j/njet.png", "prefit/emu_ge1j/njet_log.png", "prefit/emu_ge2j/mll.png",
                      "postfit/emu_ge1j_njet.png", "impacts.png", "cutflow.png")
                @test joinpath(work, "plot", p) in files
            end
        else
            @test_skip "native ROOT not available: plots not rendered"
        end

        # cached rerun; a [plot]-only change reruns plot but not fit
        sm2 = run_pipeline(RunOptions(cfgp; workdir = work))
        @test all(v["run"] == 0 for v in values(sm2))
        write_analysis(dir; plot_extra = "prefit = false\n")
        sm3 = run_pipeline(RunOptions(cfgp; workdir = work, steps = [:fit, :plot]))
        @test sm3[:fit]["run"] == 0 && sm3[:plot]["run"] == 1
        files3 = String.(JSON3.read(read(joinpath(work, "plot", "index.json"), String))[:files])
        @test !any(f -> occursin("/prefit/", f), files3)

        # CLI keeps working through the fit and plot steps
        @test main(["run", cfgp, "--workdir", work, "--from", "fit", "--force"]) == 0
    end
end
end
