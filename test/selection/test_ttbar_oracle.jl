module TestTTbarOracle
# The compiled ttbar_emu definition must reproduce, event by event and bit by
# bit, an independent re-implementation of the reference TTbarEmu.jl logic.
using Test, Random
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Histograms
using ..SyntheticEvents

const TTBAR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu", "analysis.toml"))

# ---- oracle (reference definitions, written independently of Cascade) ----
ele_ok(c, i, ptmin) = c["Electron_pt"][i] > ptmin && abs(c["Electron_eta"][i]) < 2.4 &&
    !(1.444 < abs(c["Electron_eta"][i] + c["Electron_deltaEtaSC"][i]) < 1.566) && c["Electron_cutBased"][i] >= 4
mu_ok(c, i, ptmin) = c["Muon_pt"][i] > ptmin && abs(c["Muon_eta"][i]) < 2.4 && c["Muon_tightId"][i] &&
    c["Muon_pfRelIso04_all"][i] < 0.15
dr(eta1, phi1, eta2, phi2) = hypot(eta1 - eta2, mod(phi1 - phi2 + π, 2π) - π)
mll(pt1, eta1, phi1, pt2, eta2, phi2) = sqrt(max(2pt1 * pt2 * (cosh(eta1 - eta2) - cos(phi1 - phi2)), 0.0))
function ref_trigger(emu, smu, sele, stream)
    stream == "MC" && return emu || smu || sele
    stream == "MuonEG" && return emu
    stream == "Muon" && return smu && !emu
    return sele && !emu && !smu
end

"Per-event view of the synthetic columns."
event(cols, i) = Dict(k => (v isa Jagged ? collect(v[i]) : v[i]) for (k, v) in cols)

"Returns (stage, fills::Vector{(hist, value)})"
function oracle(c, stream, golden)
    s = 0
    if stream != "MC"
        (356309 <= c["run"] <= 356615 && any(a <= c["luminosityBlock"] <= b for (a, b) in get(golden, Int(c["run"]), []))) || return s, nothing
        s += 1
    end
    emu = c[HLT_PATHS[1]] || c[HLT_PATHS[2]]
    ref_trigger(emu, c[HLT_PATHS[3]], c[HLT_PATHS[4]], stream) || return s, nothing
    s += 1
    ie = [i for i in eachindex(c["Electron_pt"]) if ele_ok(c, i, 35.0)]
    im = [i for i in eachindex(c["Muon_pt"]) if mu_ok(c, i, 35.0)]
    (length(ie) == 1 && length(im) == 1) || return s, nothing
    s += 1
    (count(i -> ele_ok(c, i, 10.0), eachindex(c["Electron_pt"])) == 1 &&
     count(i -> mu_ok(c, i, 10.0), eachindex(c["Muon_pt"])) == 1) || return s, nothing
    s += 1
    a, b = ie[1], im[1]
    c["Electron_charge"][a] * c["Muon_charge"][b] < 0 || return s, nothing
    s += 1
    m = mll(c["Electron_pt"][a], c["Electron_eta"][a], c["Electron_phi"][a], c["Muon_pt"][b], c["Muon_eta"][b], c["Muon_phi"][b])
    m > 20.0 || return s, nothing
    s += 1
    leps = ((c["Electron_eta"][a], c["Electron_phi"][a]), (c["Muon_eta"][b], c["Muon_phi"][b]))
    jets = [i for i in eachindex(c["Jet_pt"]) if c["Jet_pt"][i] > 30.0 && abs(c["Jet_eta"][i]) < 2.4 &&
            (c["Jet_jetId"][i] & 2) != 0 && all(dr(c["Jet_eta"][i], c["Jet_phi"][i], η, φ) > 0.4 for (η, φ) in leps)]
    nj = length(jets)
    nj >= 1 || return s, nothing
    s += 1
    nj >= 2 && (s += 1)
    jo = sort(collect(jets); by = k -> c["Jet_pt"][k], rev = true)
    fills = Any[("lep_pt", c["Electron_pt"][a]), ("lep_pt", c["Muon_pt"][b]), ("lep_eta", c["Electron_eta"][a]),
                ("lep_eta", c["Muon_eta"][b]), ("jet1_pt", c["Jet_pt"][jo[1]]), ("jet1_eta", c["Jet_eta"][jo[1]])]
    nj >= 2 && push!(fills, ("jet2_pt", c["Jet_pt"][jo[2]]))
    nj >= 3 && push!(fills, ("jet3_pt", c["Jet_pt"][jo[3]]))
    push!(fills, ("mll", m), ("njet", nj))
    return s, fills
end

function ref_fill!(h, x, w)        # fill_control.jl semantics
    x < h.edges[1] && return
    i = min(searchsortedlast(h.edges, x), length(h.sumw))
    h.sumw[i] += w; h.sumw2[i] += w^2
end

function read_golden(path)          # reference regex parser
    g = Dict{Int,Vector{Tuple{Int,Int}}}()
    for m in eachmatch(r"\"(\d+)\"\s*:\s*\[((?:\s*\[\s*\d+\s*,\s*\d+\s*\]\s*,?)*)\s*\]", read(path, String))
        g[parse(Int, m[1])] = [(parse(Int, p[1]), parse(Int, p[2])) for p in eachmatch(r"\[\s*(\d+)\s*,\s*(\d+)\s*\]", m[2])]
    end
    return g
end

@testset "ttbar_emu selection == reference logic (synthetic)" begin
    cfg = load_analysis(TTBAR)
    golden = read_golden(cfg.data_quality.golden_json)
    lm = load_lumimask(cfg.data_quality.golden_json; run_min = cfg.data_quality.run_min, run_max = cfg.data_quality.run_max)
    rng = MersenneTwister(20261104)
    n = 20_000
    for (kind, stream, refstream) in ((:mc, "", "MC"), (:data, "MuonEG", "MuonEG"), (:data, "Muon", "Muon"),
                                      (:data, "EGamma", "EGamma"))
        cols = synthetic_events(rng, n)
        if kind === :data                   # 80% of events in certified lumi sections inside the run range
            good = [(r, l) for (r, rs) in golden if 356309 <= r <= 356615 for (a, b) in rs for l in a:min(b, a + 5)]
            for i in 1:n
                rand(rng) < 0.8 || continue
                r, l = rand(rng, good)
                cols["run"][i] = r; cols["luminosityBlock"][i] = l
            end
        end
        sel = compile_selection(cfg, kind)
        table, cf = run_selection(sel, MemorySource(cols, n); stream, lumimask = kind === :data ? lm : nothing,
                                  sample = "s")
        ref_stage = zeros(Int, n)
        ref_h = Dict(r.name => Dict(h.name => BinnedHist(h.edges) for h in cfg.histograms) for r in cfg.regions)
        rstage = region_stages(cfg, kind)
        ref_cf_w = zeros(length(cf.names)); ref_cf_n = zeros(Int, length(cf.names))
        for i in 1:n
            c = event(cols, i)
            s, fills = oracle(c, refstream, golden)
            ref_stage[i] = s
            w = kind === :mc ? Float64(c["genWeight"]) : 1.0
            for k in 1:s+1
                ref_cf_w[k] += w; ref_cf_n[k] += 1
            end
            fills === nothing && continue
            for r in cfg.regions
                s >= rstage[r.name] || continue
                for (hn, x) in fills
                    ref_fill!(ref_h[r.name][hn], x, w)
                end
            end
        end
        @testset "$kind $stream" begin
            @test cf.n == ref_cf_n
            @test cf.sumw == ref_cf_w
            kept = table["entry"]
            @test kept == [i for i in 1:n if ref_stage[i] >= sel.keep_stage]
            @test table["stage"] == ref_stage[kept]
            @test cf.n[end] >= (kind === :mc ? 20 : 1)    # the full selection is exercised
            regions = [r.name => Bool[x >= rstage[r.name] for x in table["stage"]] for r in cfg.regions]
            values = Dict{String,Any}(h.name => Vector{Float64}[table[c] for c in table.meta["hist_columns"][h.name]]
                                      for h in cfg.histograms)
            st = fill_store!(HistogramStore(), "s", cfg.histograms, values, regions, [NOMINAL => table["weight"]])
            for r in cfg.regions, h in cfg.histograms
                @test st[r.name, "s", NOMINAL, h.name] == ref_h[r.name][h.name]
            end
        end
    end
end
end
