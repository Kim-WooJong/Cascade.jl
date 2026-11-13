module TestBatchShape
using Test, TOML, JSON3, Cascade
using Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline
using ..TestShapePipeline
const S = TestShapePipeline
@testset "batch scalar shape raw theory and cutflow exactness" begin
    mktempdir() do dir
        p = S.setup(dir)
        for (s, nf) in S.FILES, k in 1:nf
            file = joinpath(dir, "inputs", s, "f$k.cols")
            c, m, _ = read_column_file(file)
            c["PSWeight"] = Jagged([[1.2, .8] for _ in eachindex(c["genWeight"])])
            write_column_file(file, c; meta = m)
        end
        raw = TOML.parsefile(p)
        raw["batch"] = Dict("workers" => 2, "threads" => 1)
        raw["hooks"] = Dict("correct" => "Cascade.Systematics.apply_corrections")
        raw["corrections"] = Dict("flat" => [Dict("name" => "sf", "nominal" => 2., "up" => 2.2, "down" => 1.8)])
        raw["theory_weights"] = [Dict("name" => "ISR", "branch" => "PSWeight", "family" => "ps", "normalization" => "relative",
            "reduction" => "pair", "indices" => [1, 2], "expected_length" => 2, "samples" => ["sigA"], "convention" => "synthetic pair")]
        open(io -> TOML.print(io, raw), p, "w")
        serial = joinpath(dir, "serial")
        run_pipeline(RunOptions(p; workdir = serial, steps = [:skim, :select, :correct, :histogram, :merge, :systematics]))
        work = joinpath(dir, "batch"); m = batch_plan(RunOptions(p; workdir = work))
        @test batch_run(work; workers = 2)["complete"]
        # Missing/corrupt shape companions invalidate the whole receipt while
        # nominal artifacts and metadata remain intact; fresh retry repairs it.
        task = first(m["tasks"]); cfg = load_analysis(p)
        for step in (:select, :correct)
            verified = Cascade.Pipeline.batch_receipt(work, m, cfg, task)
            name, chunk = task["sample"], task["entry"]["chunk"]
            main = Cascade.Pipeline.chunk_path(verified.dir, step, name, chunk, ".cols")
            before = read(main); meta = read(main * ".meta.json")
            ms = Cascade.Pipeline.read_meta(Cascade.Pipeline.chunk_path(verified.dir, :select, name, chunk, ".cols"))
            companion = Cascade.Pipeline.shape_chunk_path(verified.dir, step, name, chunk, first(ms["shape"]), ".cols")
            step == :select ? rm(companion) : write(companion, "corrupt shape")
            @test read(main) == before
            @test read(main * ".meta.json") == meta
            @test !batch_status(work)["complete"]
            @test_throws Exception batch_merge(work)
            @test batch_run(work; workers = 1)["complete"]
        end
        result = batch_merge(work)
        for rel in ("merge/histograms_raw.json", "merge/histograms.json", "systematics/templates.json")
            a = read_store(joinpath(serial, rel)); b = read_store(joinpath(result, rel))
            @test Set(keys(a)) == Set(keys(b)); @test a.meta == b.meta
            for k in keys(a), field in (:edges, :sumw, :sumw2)
                @test reinterpret(UInt64, getfield(a[k], field)) == reinterpret(UInt64, getfield(b[k], field))
            end
        end
        @test JSON3.read(read(joinpath(serial, "merge/samples.json"), String)) == JSON3.read(read(joinpath(result, "merge/samples.json"), String))
        for rel in ("merge/yields.tsv", "merge/shape_yields.tsv")
            @test read(joinpath(serial, rel)) == read(joinpath(result, rel))
        end
    end
end
end
