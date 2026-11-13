@testset "deterministic process batch execution and verified resume" begin
    mktempdir() do dir
        p = batch_fixture(dir); serial = joinpath(dir, "serial")
        run_pipeline(RunOptions(p; workdir = serial, steps = [:skim, :select, :correct, :histogram, :merge, :systematics, :fit]))
        work = joinpath(dir, "batch"); m = batch_plan(RunOptions(p; workdir = work))
        @test length(m["tasks"]) == 3
        @test !batch_status(work)["complete"]
        @test BP.main(["batch", "status", work]) == 3
        @test_throws Exception batch_merge(work)
        @test_throws Exception batch_plan(RunOptions(p; workdir = work))
        # Reverse order, then process orchestration fills remaining work.
        id = last(m["tasks"])["id"]
        run(BP.batch_command(work, id, 1))
        receipt = read(joinpath(work, "receipts", id * ".json"))
        @test batch_run(work; workers = 2)["complete"]
        @test length(readdir(joinpath(work, "receipts"))) == length(m["tasks"])
        @test read(joinpath(work, "receipts", id * ".json")) == receipt
        @test batch_worker(work, id)["status"] == "reused"
        result = batch_merge(work; steps = [:merge, :systematics, :fit])
        batch_compare(serial, result)
        @test batch_merge(work; steps = [:merge, :systematics, :fit]) == result
        @test BP.main(["batch", "status", work]) == 0
        @test batch_run(work; workers = 1)["complete"]
        one = joinpath(dir, "one-worker")
        mone = batch_plan(RunOptions(p; workdir = one))
        @test [t["id"] for t in mone["tasks"]] == [t["id"] for t in m["tasks"]]
        @test batch_run(one; workers = 1)["complete"]
        batch_compare(serial, batch_merge(one; steps = [:merge, :systematics, :fit]))
        @test JSON3.read(read(joinpath(result, "merge/samples.json"), String))["samples"]["mc"]["gen_weight_sum"] == -4.
        raw = read_store(joinpath(result, "merge/histograms_raw.json"))
        @test raw["signal", "mc", "__theory_scale_1", "x"].sumw == [-6.]
        templates = read_store(joinpath(result, "systematics/templates.json"))
        @test templates["signal", "mc", "scaleDown", "x"].sumw == [4.]
        # Taskwise down envelopes give 3, not the correct complete-merge value 4.
        @test templates["signal", "mc", "scaleDown", "x"].sumw != [3.]
        # Corruption, foreign receipts and extra/partial receipts fail before merge.
        task = first(m["tasks"]); verified = BP.batch_receipt(work, m, load_analysis(p), task)
        hist = BP.chunk_path(verified.dir, :histogram, "mc", task["entry"]["chunk"], ".json")
        write(hist, "corrupt")
        @test !batch_status(work)["complete"]
        @test_throws Exception batch_merge(work)
        @test batch_run(work; workers = 1)["complete"]
        @test length(readdir(joinpath(work, "attempts", task["id"]))) == 2
        path = joinpath(work, "receipts", task["id"] * ".json"); good = read(path)
        r = BP._jsdict(JSON3.read(String(copy(good)))); r["manifest"] = "foreign"; BP.batch_atomic_json(path, r)
        @test !batch_status(work)["complete"]
        @test_throws Exception batch_merge(work)
        write(path, good)
        extra = joinpath(work, "receipts", "extra.json"); write(extra, "partial")
        @test !batch_status(work)["complete"]
        @test_throws Exception batch_run(work)
        rm(extra)
        rm(path); write(path * ".partial", "{")
        @test_throws Exception batch_merge(work)
        rm(path * ".partial")
        @test batch_run(work; workers = 2)["complete"]
        # Source signatures and original TOML bytes are pinned, including reduction-only edits.
        original = read(p); write(p, String(copy(original)) * "\n# changed\n")
        @test_throws Exception batch_status(work)
        write(p, original)
        input = joinpath(dir, "f1.cols"); touch(input)
        @test_throws Exception batch_status(work)
    end
end
