module TestExposureYields
using Test, TOML, JSON3
import Cascade
using Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline
const P = Cascade.Pipeline
const STEPS = [:skim, :select, :correct, :histogram, :merge]

function fixture(dir; mode = "configured", acknowledge = true)
    write(joinpath(dir, "golden.json"), """{"10":[[1,2]],"11":[[1,2]],"12":[[1,1]]}""")
    write(joinpath(dir, "per_ls.json"), """{"10":{"1":1.0,"2":2.0},"11":{"1":3.0,"2":4.0}}""")
    for k in 1:2
        write_column_file(joinpath(dir, "mc", "f$k.cols"),
            Dict("x" => [0.5, 1.5, 3.0, -1.0], "genWeight" => ones(4));
            meta = Dict("gen_weight_sum" => 4.0))
    end
    for (sample, k, runs, ls) in (("dataA", 1, [10,10,10,12], [1,2,2,1]),
                                  ("dataA", 2, [11], [2]),
                                  ("dataB", 1, [10,11], [2,1]),
                                  ("dataB", 2, [11], [2]))
        write_column_file(joinpath(dir, sample, "f$k.cols"),
            Dict("x" => ones(length(runs)), "runNumber" => runs, "lsNumber" => ls))
    end
    d = Dict{String,Any}(
        "analysis" => Dict("name" => "exposure", "lumi_pb" => 100.0),
        "samples" => [Dict("name" => s, "kind" => s == "mc" ? "mc" : "data", "format" => "cols",
            "files" => ["$s/*.cols"], "xsec_pb" => 2.0) for s in ("mc", "dataA", "dataB")],
        "data_quality" => Dict("golden_json" => "golden.json", "run_range" => [10,11],
            "run_branch" => "runNumber", "lumi_branch" => "lsNumber"),
        "luminosity" => Dict("mode" => mode, "file" => "per_ls.json", "unit" => "pb^-1",
            "assume_complete_lumisections" => acknowledge),
        "variables" => Dict("v" => "x"),
        "cuts" => [Dict("name" => "cert", "expr" => "lumimask", "only" => "data"),
                   Dict("name" => "positive", "expr" => "x > 0")],
        "regions" => [Dict("name" => "selected", "after" => "positive")],
        "histograms" => [Dict("name" => "v", "edges" => [1.0,2.0], "values" => ["v", "v"])],
        "weights" => Dict("mc" => ["genWeight"]),
        "merge" => Dict("yield_variable" => "v"))
    path = joinpath(dir, "analysis.toml")
    open(io -> TOML.print(io, d), path, "w")
    return path, d
end

savecfg(path, d) = open(io -> TOML.print(io, d), path, "w")
metadata(work) = JSON3.read(read(joinpath(work, "merge", "samples.json"), String))

@testset "explicit luminosity table validation and deduplicated sums" begin
    mktempdir() do dir
        path, raw = fixture(dir)
        table = P.load_lumisection_luminosity(joinpath(dir, "per_ls.json"))
        @test P.lumisection_luminosity([[10,1],[10,2],[10,1]], table) == 3.0
        @test P.lumisection_luminosity(reverse([[10,1],[10,2],[11,1]]), table) == 6.0
        @test_throws ArgumentError P.lumisection_luminosity([[99,1]], table)
        for (key, value) in (("mode", "automatic"), ("unit", "fb^-1"), ("assume_complete_lumisections", "yes"))
            bad = deepcopy(raw); bad["luminosity"][key] = value
            @test_throws ArgumentError P.luminosity_spec(parse_analysis(bad; dir))
        end
        configured = deepcopy(raw)
        delete!(configured, "luminosity")
        @test P.luminosity_spec(parse_analysis(configured; dir))["mode"] == "configured"
        for invalid in ("{\"10\": {\"1\": -1}}", "{\"10\": {\"1\": true}}", "{\"10\": {\"1\": \"1\"}}",
                        "{\"10\": [[1,2]]}", "{\"10\": {\"0\": 1}}", "{\"10\": {\"1\": 1}, \"010\": {\"1\":2}}")
            write(joinpath(dir, "invalid.json"), invalid)
            @test_throws ArgumentError P.load_lumisection_luminosity(joinpath(dir, "invalid.json"))
        end
    end
end

@testset "configured subset normalization is unchanged and exposure honest" begin
    mktempdir() do dir
        path, _ = fixture(dir)
        work = joinpath(dir, "work")
        run_pipeline(RunOptions(path; workdir = work, steps = STEPS, max_files = 1))
        m = metadata(work); e = m.luminosity
        @test m.lumi_pb == 100.0
        @test e.lumi_used_pb == e.lumi_configured_pb == 100.0
        @test e.observed_lumisection_lumi_pb === nothing
        @test e.exposure_status == "unknown"
        @test e.truncated
        @test e.selected_nfiles == 3 && e.available_nfiles == 6
        @test m.samples.mc.norm == luminosity_scale(2.0, 1.0, 100.0, 4.0)
        r = m.samples.mc.regions.selected
        @test r.selected_event_count == r.n == 3
        @test r.cutflow_yield == r["yield"] == 150.0
        @test r.histogram_integral == r.hist_yield == 200.0
        @test r.histogram_integral != r.cutflow_yield
        @test r.histogram_variable == "v"
        @test read_store(joinpath(work, "merge", "histograms.json")).meta["luminosity"]["lumi_used_pb"] == 100.0
        @test read_store(joinpath(work, "merge", "histograms_raw.json")).meta["normalised"] == false
        tsv = read(joinpath(work, "merge", "yields.tsv"), String)
        @test occursin("selected_event_count\tcutflow_sumw_raw\tcutflow_yield\thistogram_integral", tsv)
        @test all(x["run"] == 0 for x in values(run_pipeline(RunOptions(path; workdir = work, steps = STEPS, max_files = 1))))
    end
end

@testset "certified observed LS union, payload cache, and completeness assumption" begin
    mktempdir() do dir
        path, d = fixture(dir; mode = "certified", acknowledge = false)
        @test_throws ArgumentError P.luminosity_spec(load_analysis(path))
        d["luminosity"]["assume_complete_lumisections"] = true
        savecfg(path, d)
        work = joinpath(dir, "work")
        opts = RunOptions(path; workdir = work, steps = STEPS, max_files = 1)
        run_pipeline(opts)
        m = metadata(work); e = m.luminosity
        @test e.lumi_used_pb == e.observed_lumisection_lumi_pb == 6.0
        @test e.lumi_configured_pb == 100.0
        @test e.exposure_status == "assumed_complete_observed_lumisections"
        @test e.assume_complete_lumisections && e.truncated
        @test e.certified_observed_lumisection_count == 3
        @test collect.(e.certified_observed_lumisections) == [[10,1],[10,2],[11,1]]
        @test e.samples.dataA.certified_observed_lumisection_count == 2
        @test e.samples.dataB.certified_observed_lumisection_count == 2
        @test m.samples.mc.norm == 3.0
        @test m.samples.mc.regions.selected.cutflow_yield == 9.0
        @test all(x["run"] == 0 for x in values(run_pipeline(opts)))
        # Same path, changed table content: skim coverage is rebound to the new
        # payload; selection/histograms stay cached, normalization is recomputed.
        write(joinpath(dir, "per_ls.json"), """{"10":{"1":2.0,"2":2.0},"11":{"1":3.0,"2":4.0}}""")
        sm = run_pipeline(opts)
        @test sm[:skim]["run"] == 3 && sm[:merge]["run"] == 1
        @test sm[:select]["run"] == sm[:histogram]["run"] == 0
        @test metadata(work).luminosity.lumi_used_pb == 7.0
        # Full file set adds 11/2 exactly once, despite its appearance in both PDs.
        run_pipeline(RunOptions(path; workdir = work, steps = STEPS))
        e = metadata(work).luminosity
        @test e.lumi_used_pb == 11.0 && !e.truncated
        @test e.certified_observed_lumisection_count == 4
        # Certification content changes at the same path invalidate coverage.
        write(joinpath(dir, "golden.json"), """{"10":[[1,1]],"11":[[1,2]],"12":[[1,1]]}""")
        sm = run_pipeline(RunOptions(path; workdir = work, steps = STEPS))
        @test sm[:skim]["run"] == 3 && sm[:merge]["run"] == 1
        @test metadata(work).luminosity.lumi_used_pb == 9.0
        @test metadata(work).luminosity.certified_observed_lumisection_count == 3
        # Cached coverage must not be reused with a different table payload.
        write(joinpath(dir, "per_ls.json"), """{"10":{"1":3.0,"2":2.0},"11":{"1":3.0,"2":4.0}}""")
        @test_throws ArgumentError run_pipeline(RunOptions(path; workdir = work, steps = [:merge]))
        # Missing certified table entries fail, not a partial sum.
        write(joinpath(dir, "per_ls.json"), """{"10":{"1":2.0,"2":2.0},"11":{"2":4.0}}""")
        @test_throws ArgumentError run_pipeline(RunOptions(path; workdir = work, steps = STEPS))
    end
end

@testset "yield naming compatibility" begin
    y = P.region_yield_record(3, 2.0, 4.0; histogram_integral = 12.0, histogram_variable = "x")
    @test y["selected_event_count"] == y["n"] == 3
    @test y["cutflow_sumw_raw"] == y["sumw"] == 2.0
    @test y["cutflow_yield"] == y["yield"] == 8.0
    @test y["histogram_integral"] == y["hist_yield"] == 12.0
    @test P.region_yield_record(1, 1.0, 1.0)["histogram_integral"] === nothing
end
end
