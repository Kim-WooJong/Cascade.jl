@testset "manifest, payload, inventory and code contract rejection" begin
    mktempdir() do dir
        p = batch_fixture(dir)
        payload = joinpath(dir, "payload.json"); write(payload, "{}")
        d = TOML.parsefile(p); d["corrections"]["sets"] = Dict("unused" => payload)
        open(io -> TOML.print(io, d), p, "w")
        work = joinpath(dir, "batch"); m = batch_plan(RunOptions(p; workdir = work))
        path = joinpath(work, "manifest.json"); original = read(path)
        for mutation in (:checksum, :code, :duplicate, :task, :extraction)
            bad = deepcopy(m)
            if mutation == :checksum
                bad["workers"] = 9
            elseif mutation == :code
                bad["fingerprint"]["source"] = "foreign"
            elseif mutation == :duplicate
                push!(bad["tasks"], first(bad["tasks"]))
            elseif mutation == :task
                bad["tasks"][1]["entry"]["gen_weight_sum"] = 123.
            else
                bad["fingerprint"]["extraction"] = Dict()
            end
            if mutation != :checksum
                delete!(bad, "id"); bad["id"] = BP.batch_hash(bad)
            end
            BP.batch_atomic_json(path, bad)
            @test_throws Exception batch_status(work)
            @test_throws Exception batch_worker(work, first(m["tasks"])["id"])
        end
        write(path, original)
        write(payload, "{ }")
        @test_throws Exception batch_status(work)
        write(payload, "{}")
        @test !batch_status(work)["complete"]
        extra = joinpath(dir, "f3.cols"); cp(joinpath(dir, "f1.cols"), extra)
        @test_throws Exception batch_status(work)
        rm(extra)
        @test !batch_status(work)["complete"]
        @test_throws ArgumentError batch_worker(work, "../foreign")
        @test BP.main(["batch", "worker", work, "foreign"]) == 1
        @test BP.main(["batch", "unknown"]) == 2
        subset = batch_plan(RunOptions(p; workdir = joinpath(dir, "subset"), samples = ["mc"], max_files = 1))
        @test length(subset["tasks"]) == 1
        @test subset["skims"]["mc"]["truncated"] == true
        @test subset["skims"]["mc"]["available_nfiles"] == 2
        @test subset["max_files"] == 1
    end
end
