@testset "published plot references and immutable global phases" begin
    mktempdir() do dir
        p = batch_fixture(dir)
        raw = TOML.parsefile(p)
        raw["plot"] = Dict("prefit" => false, "postfit" => false, "cutflow" => false, "impacts" => false, "tables" => true)
        open(io -> TOML.print(io, raw), p, "w")
        work = joinpath(dir, "batch"); batch_plan(RunOptions(p; workdir = work))
        @test batch_run(work; workers = 2)["complete"]
        @test BP.main(["batch", "merge", work, "--through", "plot"]) == 0
        result = joinpath(work, "result")
        index = JSON3.read(read(joinpath(result, "plot/index.json"), String))
        @test !isempty(index["files"])
        @test any(endswith("yields.txt"), String.(index["files"]))
        @test any(endswith(".tex"), String.(index["files"]))
        for path in index["files"]
            @test isfile(path)
            @test BP.batch_safe_path(path; root = result) == path
            @test !occursin("/merges/", path)
        end
        before = BP.batch_files(result)
        @test BP.main(["batch", "merge", work, "--through", "plot"]) == 0
        @test BP.batch_files(result) == before
        @test_throws Exception batch_merge(work; steps = [:merge])
        @test BP.batch_files(result) == before
        # A fabricated index cannot reference scientific inputs or absent outputs.
        stage = mktempdir(dir)
        BP.batch_atomic_json(joinpath(stage, "plot/index.json"), Dict("files" => [p]))
        @test_throws Exception BP.batch_rebase_outputs(stage, result)
        BP.batch_atomic_json(joinpath(stage, "plot/index.json"), Dict("files" => [joinpath(stage, "missing")]))
        @test_throws Exception BP.batch_rebase_outputs(stage, result)
    end
end

@testset "batch output-bearing names reject before filesystem side effects" begin
    mktempdir() do dir
        p = batch_fixture(dir); original = TOML.parsefile(p)
        outside = joinpath(dir, "outside"); mkpath(outside)
        write(joinpath(outside, "sentinel"), "preserve")
        expected = BP.batch_files(outside)
        for kind in (:region, :histogram, :channel, :plot_region, :plot_variable),
            name in ("../outside/escape", joinpath(outside, "absolute"))
            raw = deepcopy(original)
            raw["plot"] = Dict{String,Any}("prefit" => false, "postfit" => false, "tables" => true)
            if kind == :region
                raw["regions"] = [Dict("name" => name, "after" => "all")]
            elseif kind == :histogram
                raw["histograms"][1]["name"] = name
            elseif kind == :channel
                raw["fit"]["channels"][1]["name"] = name
            else
                raw["plot"][kind == :plot_region ? "regions" : "variables"] = [name]
            end
            open(io -> TOML.print(io, raw), p, "w")
            # Serial parsing intentionally still permits these names.
            cfg = load_analysis(p)
            @test_throws ArgumentError BP.batch_validate_names(cfg)
            work = joinpath(dir, "reject")
            @test_throws ArgumentError batch_plan(RunOptions(p; workdir = work))
            @test !ispath(work)
            @test !ispath(work * ".plan.lock")
            @test BP.batch_files(outside) == expected
            @test readdir(outside) == ["sentinel"]
        end
        # Finalization independently checks names even for a rechecksummed manifest.
        open(io -> TOML.print(io, original), p, "w")
        work = joinpath(dir, "batch"); m = batch_plan(RunOptions(p; workdir = work))
        original["fit"]["channels"][1]["name"] = "../../outside/escape"
        open(io -> TOML.print(io, original), p, "w")
        cfg = load_analysis(p)
        m["config_sha256"] = bytes2hex(BP.sha256(read(p)))
        m["resolved"] = cfg.raw
        m["fingerprint"] = BP.batch_fingerprint(cfg)
        delete!(m, "id"); m["id"] = BP.batch_hash(m)
        BP.batch_atomic_json(joinpath(work, "manifest.json"), m)
        @test_throws ArgumentError batch_merge(work; steps = [:merge, :systematics, :fit, :plot])
        @test !ispath(joinpath(work, "merges"))
        @test BP.batch_files(outside) == expected
    end
end

@testset "preexisting symlink ancestry rejects before temporary writes or launch" begin
    mktempdir() do dir
        p = batch_fixture(dir)
        outside = joinpath(dir, "outside"); mkpath(outside)
        write(joinpath(outside, "sentinel"), "preserve")
        expected = BP.batch_files(outside)
        for sub in ("attempts", "merges", "launches", "receipts", "locks")
            work = joinpath(dir, sub); m = batch_plan(RunOptions(p; workdir = work))
            symlink(outside, joinpath(work, sub))
            @test_throws Exception batch_worker(work, first(m["tasks"])["id"])
            @test_throws Exception batch_run(work)
            @test_throws Exception batch_merge(work)
            @test readdir(outside) == ["sentinel"]
            @test BP.batch_files(outside) == expected
        end
        work = joinpath(dir, "child"); m = batch_plan(RunOptions(p; workdir = work))
        id = first(m["tasks"])["id"]
        mkpath(joinpath(work, "attempts")); symlink(outside, joinpath(work, "attempts", id))
        @test_throws Exception batch_worker(work, id)
        launchwork = joinpath(dir, "child-launch")
        lm = batch_plan(RunOptions(p; workdir = launchwork))
        secondid = lm["tasks"][2]["id"]
        mkpath(joinpath(launchwork, "launches"))
        symlink(outside, joinpath(launchwork, "launches", secondid))
        @test_throws Exception batch_run(launchwork)
        @test !ispath(joinpath(launchwork, "attempts"))
        @test readdir(joinpath(launchwork, "launches")) == [secondid]
        alias = joinpath(dir, "alias"); symlink(outside, alias)
        @test_throws Exception batch_plan(RunOptions(p; workdir = joinpath(alias, "new")))
        @test_throws Exception BP.batch_atomic_json(joinpath(alias, "new.json"), Dict())
        @test readdir(outside) == ["sentinel"]
        @test BP.batch_files(outside) == expected
    end
end
