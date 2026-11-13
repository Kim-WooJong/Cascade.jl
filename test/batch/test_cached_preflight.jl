@testset "cached histogram and merge extraction preflight" begin
    mktempdir() do dir
        p = batch_fixture(dir); work = joinpath(dir, "serial")
        steps = [:skim, :select, :correct, :histogram, :merge]
        run_pipeline(RunOptions(p; workdir = work, steps))
        for step in (:histogram, :merge)
            @test run_pipeline(RunOptions(p; workdir = work, steps = [step]))[step]["run"] == 0
        end
        raw = TOML.parsefile(p)
        changed = deepcopy(raw)
        changed["theory_weights"][1]["normalization"] = "central"
        changed["theory_weights"][1]["central_index"] = 2
        open(io -> TOML.print(io, changed), p, "w")
        for step in (:histogram, :merge)
            @test_throws ArgumentError run_pipeline(RunOptions(p; workdir = work, steps = [step]))
        end
        # Reduction/CL-only edits preserve extracted values and intermediate caches.
        changed = deepcopy(raw)
        merge!(changed["theory_weights"][1], Dict("family" => "pdf", "reduction" => "replica_std",
            "cl_scale" => .5, "pdf_template_model" => "rank_one"))
        open(io -> TOML.print(io, changed), p, "w")
        for step in (:histogram, :merge)
            @test run_pipeline(RunOptions(p; workdir = work, steps = [step]))[step]["run"] == 0
        end
        # Cached destination corruption must not bypass validation either.
        open(io -> TOML.print(io, raw), p, "w")
        skim = BP.read_skim(work, "mc"); chunk = skim["files"][1]["chunk"]
        hist = BP.chunk_path(work, :histogram, "mc", chunk, ".json")
        good = read(hist); st = read_store(hist); delete!(st.meta, "theory_extraction"); write_store(hist, st)
        for step in (:histogram, :merge)
            @test_throws ArgumentError run_pipeline(RunOptions(p; workdir = work, steps = [step]))
        end
        write(hist, good)
        merged = joinpath(work, "merge/histograms.json")
        st = read_store(merged); delete!(st.meta, "theory_extraction"); write_store(merged, st)
        @test_throws ArgumentError run_pipeline(RunOptions(p; workdir = work, steps = [:merge]))
        delete!(raw, "theory_weights")
        open(io -> TOML.print(io, raw), p, "w")
        baseline = joinpath(dir, "baseline")
        run_pipeline(RunOptions(p; workdir = baseline, steps))
        a = read_store(joinpath(baseline, "merge/histograms.json"))
        @test !haskey(a.meta, "theory_extraction")
        @test Cascade.Systematics.reduce_theory(load_analysis(p), a) === a
        for step in (:histogram, :merge)
            @test run_pipeline(RunOptions(p; workdir = baseline, steps = [step]))[step]["run"] == 0
        end
    end
end
