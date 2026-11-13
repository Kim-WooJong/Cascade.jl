# Julia exposes SIGKILL but not SIGSTOP/SIGCONT constants. Native values differ
# on Linux and macOS; these tests signal only Process objects they just created.
const BATCH_SIGSTOP = Sys.isapple() ? 17 : 19
const BATCH_SIGCONT = Sys.isapple() ? 19 : 18

@testset "nonassociative MC reduction follows frozen file order, not completion" begin
    mktempdir() do dir
        p = batch_fixture(dir)
        for (i, weight) in enumerate([1.e16, -1.e16, 1.])
            write_column_file(joinpath(dir, "f$i.cols"), Dict("x" => [1.], "genWeight" => [weight]);
                meta = Dict("gen_weight_sum" => weight))
        end
        raw = TOML.parsefile(p)
        delete!(raw, "theory_weights"); delete!(raw, "fit"); delete!(raw, "corrections"); delete!(raw, "hooks")
        raw["samples"] = raw["samples"][1:1]
        open(io -> TOML.print(io, raw), p, "w")
        serial = joinpath(dir, "serial")
        run_pipeline(RunOptions(p; workdir = serial, steps = [:skim, :select, :correct, :histogram, :merge, :systematics]))
        for count in (1, 2)
            work = joinpath(dir, "batch$count"); m = batch_plan(RunOptions(p; workdir = work))
            @test length(m["tasks"]) == 3
            # Exercise one/two actual children, holding the later child after
            # partial artifacts so receipt completion is strictly reverse order.
            completion = String[]; ordered = reverse(m["tasks"])
            for start in 1:count:length(ordered)
                group = ordered[start:min(start + count - 1, length(ordered))]
                children = [run(ignorestatus(BP.batch_command(work, task["id"], 1)); wait = false) for task in group]
                try
                    if length(children) == 2
                        task = group[2]; parent = joinpath(work, "attempts", task["id"])
                        ready = () -> isdir(parent) && any(a -> isfile(BP.skim_path(joinpath(parent, a, "artifacts"), "mc")), readdir(parent))
                        @test timedwait(() -> ready() || process_exited(children[2]), 90; pollint = .005) == :ok
                        @test ready()
                        kill(children[2], BATCH_SIGSTOP)
                        @test !isfile(joinpath(work, "receipts", task["id"] * ".json"))
                    end
                    for (i, child) in enumerate(children)
                        i == 2 && kill(child, BATCH_SIGCONT)
                        wait(child); @test success(child)
                        task = group[i]
                        @test batch_status(work)["tasks"][task["id"]]["status"] == "verified"
                        push!(completion, task["id"])
                    end
                finally
                    for child in children
                        process_running(child) && (kill(child, Base.SIGKILL); wait(child))
                    end
                end
            end
            @test completion == reverse([t["id"] for t in m["tasks"]])
            @test batch_run(work; workers = count)["complete"]
            result = batch_merge(work)
            for rel in ("merge/histograms_raw.json", "merge/histograms.json", "systematics/templates.json")
                a = read_store(joinpath(serial, rel)); b = read_store(joinpath(result, rel))
                @test Set(keys(a)) == Set(keys(b))
                for k in keys(a), field in (:edges, :sumw, :sumw2)
                    @test reinterpret(UInt64, getfield(a[k], field)) == reinterpret(UInt64, getfield(b[k], field))
                end
            end
            info = JSON3.read(read(joinpath(result, "merge/samples.json"), String))
            @test info == JSON3.read(read(joinpath(serial, "merge/samples.json"), String))
            @test info["samples"]["mc"]["gen_weight_sum"] == 1.
            rawhist = read_store(joinpath(result, "merge/histograms_raw.json"))
            scaled = read_store(joinpath(result, "merge/histograms.json"))
            @test rawhist["signal", "mc", "nominal", "x"].sumw == [1.]
            @test scaled["signal", "mc", "nominal", "x"].sumw == [4.]
            @test read(joinpath(result, "merge/cutflow/mc.tsv")) == read(joinpath(serial, "merge/cutflow/mc.tsv"))
        end
        @test foldl(+, reverse([1.e16, -1.e16, 1.]); init = 0.) != 1.
    end
end

@testset "owned executing worker death retains partial attempt and retries once" begin
    mktempdir() do dir
        p = batch_fixture(dir); work = joinpath(dir, "batch")
        m = batch_plan(RunOptions(p; workdir = work)); task = first(m["tasks"]); id = task["id"]
        parent = joinpath(work, "attempts", id)
        # A fresh actual CLI worker is stopped after its isolated skim is written,
        # while selection compilation/execution is still in progress.
        proc = run(ignorestatus(BP.batch_command(work, id, 1)); wait = false)
        try
            ready = () -> isdir(parent) && any(a -> isfile(BP.skim_path(joinpath(parent, a, "artifacts"), "mc")), readdir(parent))
            @test timedwait(() -> ready() || process_exited(proc), 90; pollint = .005) == :ok
            @test ready()
            kill(proc, BATCH_SIGSTOP)
            @test process_running(proc)
            @test !isfile(joinpath(work, "receipts", id * ".json"))
            @test_throws ArgumentError BP.batch_lock(() -> nothing, joinpath(work, "locks", id * ".lock"))
            kill(proc, Base.SIGKILL); wait(proc)
            @test !success(proc)
            @test BP.batch_lock(() -> :released, joinpath(work, "locks", id * ".lock")) == :released
            @test !batch_status(work)["complete"]
            @test_throws Exception batch_merge(work)
            @test !ispath(joinpath(work, "result"))
            @test length(readdir(parent)) == 1
            @test batch_run(work; workers = 2)["complete"]
            @test length(readdir(parent)) == 2
            result = batch_merge(work; steps = [:merge, :systematics, :fit])
            serial = joinpath(dir, "serial")
            run_pipeline(RunOptions(p; workdir = serial, steps = [:skim, :select, :correct, :histogram, :merge, :systematics, :fit]))
            batch_compare(serial, result)
            @test length(readdir(joinpath(work, "receipts"))) == length(m["tasks"])
        finally
            process_running(proc) && (kill(proc, Base.SIGKILL); wait(proc))
        end
    end
end
