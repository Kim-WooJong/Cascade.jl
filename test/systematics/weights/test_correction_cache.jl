@testset "external correction inputs invalidate cached artifacts" begin
    mktempdir() do dir
        setpath = write_fixture_set(joinpath(dir, "fx.json"))
        write_sf_inputs(dir)
        # Relative payload paths must resolve against the analysis, not pwd.
        cfgp = write_sf_analysis(dir, "fx.json")
        work = joinpath(dir, "work")
        steps = [:skim, :select, :correct, :histogram, :merge]
        opts = RunOptions(cfgp; workdir = work, steps)
        run_pipeline(opts)
        before = read_store(joinpath(work, "merge", "histograms_raw.json"))
        @test all(v["run"] == 0 for v in values(run_pipeline(opts)))
        cfg = load_analysis(cfgp)
        fingerprint = Cascade.Pipeline.correction_files_key(cfg)
        oldset = Cascade.Systematics.cached_correctionset(setpath)

        # Change the payload without changing the analysis configuration.
        payload = JSON3.read(read(setpath, String), Dict{String,Any})
        for c in payload["corrections"]
            c["name"] == "lep_sf" || continue
            for category in c["data"]["content"]
                category["value"]["content"] .*= 2
            end
        end
        write(setpath, JSON3.write(payload))
        # A metadata-preserving replacement would hit an old parsed payload.
        # Seed that precise cache state without platform-specific timestamp APIs.
        Cascade.Systematics._SET_CACHE[(abspath(setpath), mtime(setpath), Int(filesize(setpath)))] = oldset
        @test Cascade.Pipeline.correction_files_key(cfg) != fingerprint
        changed = run_pipeline(opts)
        @test changed[:skim]["run"] == 0
        @test changed[:select]["run"] == 0
        @test changed[:correct]["run"] == 3
        @test changed[:histogram]["run"] == 3
        @test changed[:merge]["run"] == 1
        after = read_store(joinpath(work, "merge", "histograms_raw.json"))
        for key in keys(before)
            factor = key.sample == "sigA" ? 2.0 : 1.0
            @test after[key].sumw ≈ factor .* before[key].sumw
            @test after[key].sumw2 ≈ factor^2 .* before[key].sumw2
        end
        @test all(v["run"] == 0 for v in values(run_pipeline(opts)))

        # Simulate a new process with a changed Systematics source fingerprint.
        # Do not mutate source files or leave the process-wide cache modified.
        hashes = Cascade.Pipeline._CODE_HASHES
        original = hashes["Systematics"]
        try
            hashes["Systematics"] = "changed-systematics-source"
            changed_code = run_pipeline(RunOptions(cfgp; workdir = work, steps = [:correct]))
            @test changed_code[:correct]["run"] == 3
        finally
            hashes["Systematics"] = original
        end
        rm(setpath)
        @test_throws ArgumentError run_pipeline(RunOptions(cfgp; workdir = work, steps = [:correct]))
    end
end
