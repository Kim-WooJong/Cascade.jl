module TestRealReproduction
# Full ttbar_emu reproduction against the reference analysis outputs on gate.
# Enabled with CASCADE_REAL_DATA=1. Environment:
#   CASCADE_REAL_WORKDIR   Cascade workdir (default ~/analisis/Cascade_dev/core/scratch/real); cached steps are reused
#   CASCADE_REFERENCE_DIR  reference analysis (default ~/analisis/ttbar_ctrl: out_slim, out_data, out_cutflow)
using Test, JSON3
using Cascade.Config, Cascade.Histograms, Cascade.Pipeline

const TTBAR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu", "analysis.toml"))

function read_ref_hists(path)
    hdr = Dict(split(kv, "=")[1] => split(kv, "=")[2] for kv in split(readline(path))[2:end])
    hs = Dict{String,Tuple{Vector{Float64},Vector{Float64},Vector{Float64}}}()
    for line in Iterators.drop(eachline(path), 2)
        n, lo, hi, w, w2 = split(line, '\t')
        e, s, s2 = get!(hs, n, (Float64[], Float64[], Float64[]))
        isempty(e) && push!(e, parse(Float64, lo))
        push!(e, parse(Float64, hi)); push!(s, parse(Float64, w)); push!(s2, parse(Float64, w2))
    end
    return hdr, hs
end

function read_ref_cutflow(path)
    rows = [split(l, '\t') for l in Iterators.drop(eachline(path), 2)]
    return [r[1] for r in rows], [parse(Float64, r[2]) for r in rows], [parse(Int, r[3]) for r in rows]
end

reldiff(a, b) = a == b ? 0.0 : abs(a - b) / max(abs(a), abs(b))

if get(ENV, "CASCADE_REAL_DATA", "0") == "1"
    @testset "ttbar_emu reproduction (real data)" begin
        work = get(ENV, "CASCADE_REAL_WORKDIR", joinpath(homedir(), "analisis", "Cascade_dev", "core", "scratch", "real"))
        ref = get(ENV, "CASCADE_REFERENCE_DIR", joinpath(homedir(), "analisis", "ttbar_ctrl"))
        run_pipeline(RunOptions(TTBAR; workdir = work, steps = [:skim, :select, :correct, :histogram, :merge]))
        cfg = load_analysis(TTBAR)
        info = JSON3.read(read(joinpath(work, "merge", "samples.json"), String))[:samples]
        raw = read_store(joinpath(work, "merge", "histograms_raw.json"))
        merged = read_store(joinpath(work, "merge", "histograms.json"))
        rows = String[]
        maxrel = Ref(0.0)
        note(args...) = push!(rows, join(string.(args), '\t'))
        note("quantity", "reference", "cascade", "rel_diff")

        # ---- data: event counts per primary dataset
        refdata = Dict("MuonEG" => 5446, "SingleMuon" => 35, "Muon" => 140, "EGamma" => 284)
        tot1 = 0; tot2 = 0
        for (pd, nref) in refdata
            hdr, hs = read_ref_hists(joinpath(ref, "out_data", pd * ".tsv"))
            n1 = info[Symbol(pd)][:regions][:emu_ge1j][:n]; n2 = info[Symbol(pd)][:regions][:emu_ge2j][:n]
            @test parse(Int, hdr["pass"]) == nref
            @test n1 == nref
            @test info[Symbol(pd)][:nevents] == parse(Int, hdr["events_read"])
            @test info[Symbol(pd)][:nfiles] == parse(Int, hdr["files"])
            nref2 = Int(sum(hs["njet"][2][2:end]))
            @test n2 == nref2
            note("data_ge1_" * pd, nref, n1, 0); note("data_ge2_" * pd, nref2, n2, 0)
            tot1 += n1; tot2 += n2
            for (v, (e, s, s2)) in hs
                h = raw["emu_ge1j", pd, NOMINAL, v]
                @test h.edges == e
                @test h.sumw == s && h.sumw2 == s2
            end
        end
        @test tot1 == 5905
        @test tot2 == 3836
        note("data_ge1_total", 5905, tot1, 0); note("data_ge2_total", 3836, tot2, 0)

        # ---- MC: cutflows, generator sums, histograms, normalised yields
        y1 = 0.0; y2 = 0.0; r1 = 0.0; r2 = 0.0
        for s in filter(is_mc, cfg.samples)
            d = info[Symbol(s.name)]
            names, sumw, nraw = read_ref_cutflow(joinpath(ref, "out_cutflow", s.name * ".tsv"))
            @test String.(d[:cutflow][:names]) == names
            @test Int.(d[:cutflow][:n]) == nraw
            for k in eachindex(sumw)
                rd = reldiff(Float64(d[:cutflow][:sumw][k]), sumw[k])
                maxrel[] = max(maxrel[], rd)
                @test rd <= 1e-12
            end
            hdr, hs = read_ref_hists(joinpath(ref, "out_slim", s.name * ".tsv"))
            @test d[:nevents] == parse(Int, hdr["events_read"]) && d[:nfiles] == parse(Int, hdr["files"])
            gref = parse(Float64, hdr["gen_sumw"])
            @test reldiff(d[:gen_weight_sum], gref) <= 1e-12
            note("gen_sumw_" * s.name, gref, d[:gen_weight_sum], reldiff(d[:gen_weight_sum], gref))
            for (v, (e, sw, sw2)) in hs
                h = raw["emu_ge1j", s.name, NOMINAL, v]
                @test h.edges == e
                rd = maximum(reldiff.(h.sumw, sw); init = 0.0)
                rd2 = maximum(reldiff.(h.sumw2, sw2); init = 0.0)
                maxrel[] = max(maxrel[], rd, rd2)
                @test rd <= 1e-12 && rd2 <= 1e-12
            end
            # reference yield: sum of sigma*L/sum(gen)-scaled njet bins
            c = luminosity_scale(s.xsec_pb, s.branching_ratio, cfg.lumi_pb, gref)
            ref1 = sum(hs["njet"][2] .* c); ref2 = sum(hs["njet"][2][2:end] .* c)
            got1 = integral(merged["emu_ge1j", s.name, NOMINAL, "njet"])
            got2 = integral(merged["emu_ge2j", s.name, NOMINAL, "njet"])
            note("mc_ge1_" * s.name, ref1, got1, reldiff(got1, ref1)); note("mc_ge2_" * s.name, ref2, got2, reldiff(got2, ref2))
            note("mc_n_ge1_" * s.name, parse(Int, hdr["pass"]), d[:regions][:emu_ge1j][:n], 0)
            @test d[:regions][:emu_ge1j][:n] == parse(Int, hdr["pass"])
            y1 += got1; y2 += got2; r1 += ref1; r2 += ref2
        end
        note("mc_ge1_total", r1, y1, reldiff(y1, r1)); note("mc_ge2_total", r2, y2, reldiff(y2, r2))
        @test round(y1; digits = 4) == 6434.9316
        @test round(y2; digits = 4) == 4235.2102
        @test reldiff(y1, r1) <= 1e-12 && reldiff(y2, r2) <= 1e-12
        note("max_rel_diff_mc_bins_and_cutflow", 0, maxrel[], maxrel[])
        out = joinpath(work, "reproduction.tsv")
        write(out, join(rows, '\n') * '\n')
        println("reproduction table written to ", out)
        foreach(println, rows)
    end
else
    @info "skipping real-data reproduction (set CASCADE_REAL_DATA=1)"
end
end
