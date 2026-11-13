module TestBatchReal
using Test, TOML, JSON3, Cascade
using Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline
if get(ENV, "CASCADE_BATCH_REAL", "0") == "1"
@testset "bounded real ROOT batch and frozen p7 comparison" begin
    area = ENV["CASCADE_BATCH_AREA"]
    mkpath(area)
    config = normpath(joinpath(@__DIR__, "../../analyses/ttbar_emu/analysis.toml"))
    steps = [:skim, :select, :correct, :histogram, :merge, :systematics]
    serial = joinpath(area, "real_serial")
    run_pipeline(RunOptions(config; workdir = serial, max_files = 1, steps))
    work = joinpath(area, "real_batch")
    isdir(work) || batch_plan(RunOptions(config; workdir = work, max_files = 1))
    @test batch_run(work; workers = 2)["complete"]
    result = batch_merge(work)
    bins = 0
    for rel in ("merge/histograms_raw.json", "merge/histograms.json", "systematics/templates.json")
        a = read_store(joinpath(serial, rel)); b = read_store(joinpath(result, rel))
        @test Set(keys(a)) == Set(keys(b)); @test a.meta == b.meta
        for k in keys(a), field in (:edges, :sumw, :sumw2)
            @test reinterpret(UInt64, getfield(a[k], field)) == reinterpret(UInt64, getfield(b[k], field))
            field == :sumw && (bins += length(a[k].sumw))
        end
    end
    prior = joinpath(homedir(), "analisis/Cascade_dev/p7-theory/out_baseline")
    for file in ("histograms_raw.json", "histograms.json")
        a = read_store(joinpath(prior, "merge", file)); b = read_store(joinpath(result, "merge", file))
        @test Set(keys(a)) == Set(keys(b))
        for k in keys(a), field in (:edges, :sumw, :sumw2)
            @test reinterpret(UInt64, getfield(a[k], field)) == reinterpret(UInt64, getfield(b[k], field))
        end
    end
    info = JSON3.read(read(joinpath(result, "merge/samples.json"), String))
    @test info == JSON3.read(read(joinpath(serial, "merge/samples.json"), String))
    @test sum(s["nfiles"] for s in values(info["samples"])) == 13
    @test sum(s["nevents"] for s in values(info["samples"])) == 2200037
    @test info["luminosity"]["truncated"] == true
    @test info["lumi_pb"] == 1210.
    theory_serial = joinpath(area, "real_theory_serial")
    run_pipeline(RunOptions(config; profile = "theory_example", samples = ["TTto2L2Nu"], workdir = theory_serial, max_files = 1, steps))
    theory_work = joinpath(area, "real_theory_batch")
    isdir(theory_work) || batch_plan(RunOptions(config; profile = "theory_example", samples = ["TTto2L2Nu"], workdir = theory_work, max_files = 1))
    @test batch_run(theory_work; workers = 1)["complete"]
    theory_result = batch_merge(theory_work)
    for rel in ("merge/histograms_raw.json", "merge/histograms.json", "systematics/templates.json")
        a = read_store(joinpath(theory_serial, rel)); b = read_store(joinpath(theory_result, rel))
        @test Set(keys(a)) == Set(keys(b)); @test a.meta == b.meta
        for k in keys(a), field in (:edges, :sumw, :sumw2)
            @test reinterpret(UInt64, getfield(a[k], field)) == reinterpret(UInt64, getfield(b[k], field))
        end
    end
    # Frozen p7 used the same observed scale/PS members and nuisance names.
    old = read_store(joinpath(homedir(), "analisis/Cascade_dev/p7-theory/out_theory/merge/histograms.json"))
    new = read_store(joinpath(theory_result, "merge/histograms.json"))
    for k in keys(old)
        label = k.variation
        key = HistKey(k.region, k.sample, label, k.variable)
        @test haskey(new, key)
        haskey(new, key) || continue
        for field in (:edges, :sumw, :sumw2)
            @test reinterpret(UInt64, getfield(old[k], field)) == reinterpret(UInt64, getfield(new[key], field))
        end
    end
    write(joinpath(area, "batch-real-summary.json"), JSON3.write(Dict("files" => 13, "events" => 2200037, "compared_bins" => bins,
        "theory_events" => 32853, "coverage" => "truncated; actual exposure unknown")))
end
end
end
