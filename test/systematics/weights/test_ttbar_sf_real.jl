# Real ttbar_emu inputs on gate (CASCADE_REAL_DATA=1):
#   - every [corrections] term of the analysis.toml "sf" profile binds to the jsonpog file;
#   - CASCADE_SF_RUN=1: full run (skim..merge) with scale factors in
#     CASCADE_SF_WORKDIR (default ~/analisis/Cascade_dev/p2-weights/work_sf); writes
#     yields_sf.tsv (MC yields per variation, data/MC ratios) to the workdir.
using Cascade.Pipeline, Cascade.Histograms

const TTBAR_SF = normpath(joinpath(@__DIR__, "..", "..", "..", "analyses", "ttbar_emu", "analysis.toml"))
const TTBAR_SF_PROFILE = "sf"
const BASELINE_MC = Dict("emu_ge1j" => 6434.931560809516, "emu_ge2j" => 4235.210227397772)
const BASELINE_DATA = Dict("emu_ge1j" => 5905, "emu_ge2j" => 3836)

if get(ENV, "CASCADE_REAL_DATA", "0") == "1"
    @testset "ttbar_emu corrections bind to jsonpog 2022_Summer22" begin
        cfg = load_analysis(TTBAR_SF; profile = TTBAR_SF_PROFILE)
        spec = parse_corrections(cfg)
        for t in vcat(spec.object_sfs, spec.event_weights)
            c = cached_correctionset(t.set)[t.correction]
            b = bind_inputs(t.inputs, t.systematic, c; label = t.name)
            @test length(b) == length(c.inputs)
        end
    end
    if get(ENV, "CASCADE_SF_RUN", "0") == "1"
        @testset "ttbar_emu full run with scale factors" begin
            work = get(ENV, "CASCADE_SF_WORKDIR", joinpath(homedir(), "analisis", "Cascade_dev", "p2-weights", "work_sf"))
            run_pipeline(RunOptions(TTBAR_SF; profile = TTBAR_SF_PROFILE, workdir = work, steps = [:skim, :select, :correct, :histogram, :merge]))
            cfg = load_analysis(TTBAR_SF; profile = TTBAR_SF_PROFILE)
            merged = read_store(joinpath(work, "merge", "histograms.json"))
            mcs = [s.name for s in cfg.samples if is_mc(s)]
            datas = [s.name for s in cfg.samples if is_data(s)]
            labels = store_axis(merged, :variation)
            expected = ["nominal"; [string(n, d) for n in ("muon_id", "muon_iso", "electron_reco", "electron_id",
                                                             "pileup", "trigger_emu") for d in ("Up", "Down")]]
            @test sort(labels) == sort(expected)
            rows = ["region\tvariation\tmc_yield\trel_to_nominal\tdata\tdata_over_mc"]
            for r in ("emu_ge1j", "emu_ge2j")
                ndata = sum(integral(merged[r, d, NOMINAL, "njet"]) for d in datas)
                @test ndata == BASELINE_DATA[r]
                push!(rows, join([r, "baseline_genWeight_only", BASELINE_MC[r], "", ndata, ndata / BASELINE_MC[r]], '\t'))
                ynom = sum(integral(merged[r, s, NOMINAL, "njet"]) for s in mcs)
                for l in expected
                    y = sum(integral(merged[r, s, l, "njet"]) for s in mcs)
                    @test isfinite(y) && y > 0
                    push!(rows, join([r, l, y, y / ynom, ndata, ndata / y], '\t'))
                end
                @test sum(integral(merged[r, s, "trigger_emuUp", "njet"]) for s in mcs) == ynom
            end
            out = joinpath(work, "yields_sf.tsv")
            write(out, join(rows, '\n') * '\n')
            println("scale-factor yields written to ", out)
            foreach(println, rows)
        end
    end
else
    @info "skipping real-data scale-factor tests (set CASCADE_REAL_DATA=1)"
end
