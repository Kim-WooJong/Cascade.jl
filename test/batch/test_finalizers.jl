@testset "duplicate receipt cannot substitute for an equal-count missing task" begin
    mktempdir() do dir
        p = batch_fixture(dir); work = joinpath(dir, "batch")
        m = batch_plan(RunOptions(p; workdir = work))
        @test batch_run(work; workers = 2)["complete"]
        ids = [t["id"] for t in m["tasks"]]
        path = joinpath(work, "receipts", ids[2] * ".json")
        cp(joinpath(work, "receipts", ids[1] * ".json"), path; force = true)
        @test length(readdir(joinpath(work, "receipts"))) == length(m["tasks"])
        @test !batch_status(work)["complete"]
        @test batch_status(work)["tasks"][ids[2]]["status"] == "invalid"
        @test_throws Exception batch_merge(work)
        @test !ispath(joinpath(work, "result"))
        @test batch_run(work; workers = 1)["complete"]
    end
end

@testset "concurrent actual finalizers and failed global stage publish atomically" begin
    mktempdir() do dir
        p = batch_fixture(dir)
        raw = TOML.parsefile(p)
        # Valid, safe config names, but no such histogram: failure belongs to fit,
        # after merge/systematics have actually produced staged artifacts.
        raw["fit"]["channels"][1]["variable"] = "absent"
        open(io -> TOML.print(io, raw), p, "w")
        work = joinpath(dir, "batch"); batch_plan(RunOptions(p; workdir = work))
        @test batch_run(work; workers = 2)["complete"]
        root = dirname(dirname(@__DIR__))
        entry = joinpath(root, "bin/cascade.jl")
        log = joinpath(dir, "finalizer.log")
        io = open(log, "w")
        cmd = `$(Base.julia_cmd()) --startup-file=no --project=$root $entry batch merge $work --through fit`
        proc = run(pipeline(ignorestatus(cmd); stdout = io, stderr = io); wait = false)
        try
            staged = () -> isdir(joinpath(work, "merges")) && !isempty(readdir(joinpath(work, "merges")))
            @test timedwait(() -> staged() || process_exited(proc), 90; pollint = .005) == :ok
            @test staged()
            # The first finalizer owns the coordinator while global work runs.
            @test_throws ArgumentError batch_merge(work; steps = [:merge, :systematics, :fit])
            @test_throws ArgumentError batch_run(work)
            wait(proc); close(io)
            @test !success(proc)
            @test occursin("absent", read(log, String))
            @test !ispath(joinpath(work, "result"))
            stage = joinpath(work, "merges", only(readdir(joinpath(work, "merges"))))
            @test isfile(joinpath(stage, "merge/histograms.json"))
            @test isfile(joinpath(stage, "systematics/templates.json"))
            @test !isfile(joinpath(stage, "batch-result.json"))
            # Failure releases the coordinator and verified tasks remain reusable.
            @test batch_run(work; workers = 1)["complete"]
            result = batch_merge(work; steps = [:merge, :systematics])
            before = BP.batch_files(result)
            # Published phases are immutable; a failed incompatible upgrade cannot
            # replace a previously verified final result or alter its checksums.
            @test_throws Exception batch_merge(work; steps = [:merge, :systematics, :fit])
            @test BP.batch_files(result) == before
            @test batch_merge(work) == result
        finally
            process_running(proc) && (kill(proc, Base.SIGKILL); wait(proc))
            isopen(io) && close(io)
        end
    end
end
