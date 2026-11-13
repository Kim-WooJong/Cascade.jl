@testset "exclusive claims and interruption recovery" begin
    mktempdir() do dir
        lockpath = joinpath(dir, "claim.lock"); ready = joinpath(dir, "ready")
        script = joinpath(dir, "hold.jl")
        write(script, "using Cascade; Cascade.Pipeline.batch_lock(ARGS[1]) do; write(ARGS[2], string(getpid())); sleep(120); end")
        proc = run(`$(Base.julia_cmd()) --startup-file=no --project=$(dirname(dirname(@__DIR__))) $script $lockpath $ready`; wait = false)
        try
            @test timedwait(() -> isfile(ready) || process_exited(proc), 60) == :ok
            @test isfile(ready)
            @test_throws ArgumentError BP.batch_lock(() -> nothing, lockpath)
            kill(proc, Base.SIGKILL); wait(proc)
            @test BP.batch_lock(() -> :recovered, lockpath) == :recovered
        finally
            process_running(proc) && (kill(proc); wait(proc))
        end
    end
end
@testset "failed tasks and unverifiable hooks fail closed" begin
    mktempdir() do dir
        p = batch_fixture(dir; invalid = true); work = joinpath(dir, "batch")
        m = batch_plan(RunOptions(p; workdir = work))
        bad = m["tasks"][2]
        proc = run(ignorestatus(BP.batch_command(work, bad["id"], 1)))
        @test !success(proc)
        @test !batch_status(work)["complete"]
        @test_throws Exception batch_merge(work)
        attempts = joinpath(work, "attempts", bad["id"])
        state = JSON3.read(read(joinpath(attempts, only(readdir(attempts)), "state.json"), String))
        @test state["status"] == "failed"
        @test occursin("V", state["error"])
    end
    mktempdir() do dir
        p = batch_fixture(dir)
        register_hook!(:correct, identity; id = "not-reproducible")
        try
            @test_throws ArgumentError batch_plan(RunOptions(p; workdir = joinpath(dir, "reject")))
        finally
            delete!(BP.HOOKS, :correct)
        end
        @test builtin_source_readers()
        register_source_format!("cols", identity)
        try
            @test !builtin_source_readers()
            @test_throws ArgumentError batch_plan(RunOptions(p; workdir = joinpath(dir, "reject")))
        finally
            register_source_format!("cols", ColumnFileSource)
        end
        d = TOML.parsefile(p); d["hooks"]["correct"] = "Main.custom"
        open(io -> TOML.print(io, d), p, "w")
        @test_throws ArgumentError batch_plan(RunOptions(p; workdir = joinpath(dir, "reject")))
    end
end
