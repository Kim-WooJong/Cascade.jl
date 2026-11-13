module TestNoCheckpoints
# execution.checkpoints = false (docs/NO_CHECKPOINTS.md). AUTHORED, NOT RUN in the
# candidate stage: no Julia invocation/parse was authorized when these were written.
# Synthetic "cols" inputs only (no native ROOT/NanoAOD, no shape/theory coverage).
# The global hook registry is saved/cleared at the start of this area and restored
# in finally at its end, so hooks registered by other areas are neither seen nor lost.
using Test, Random, TOML, JSON3
import Cascade
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Histograms, Cascade.Pipeline
import Cascade.Pipeline: OrderedWindow, take_next!, shutdown_window!, window_completed, HOOKS, no_checkpoints_unsupported
include(joinpath(@__DIR__, "..", "selection", "synthetic_events.jl"))
using .SyntheticEvents

const sha256 = Cascade.Pipeline.SHA.sha256
const TTBAR = normpath(joinpath(@__DIR__, "..", "config", "fixtures", "analysis.toml"))
const TTBAR_DIR = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu"))
const ROOTDIR = normpath(joinpath(@__DIR__, "..", ".."))
const PROV = "NO_CHECKPOINTS_PROVENANCE.json"

"Synthetic ttbar_emu definition (format cols) as in test/pipeline/test_pipeline_synthetic.jl."
function write_analysis(dir; execution = "", extra = "", name = "analysis.toml")
    txt = read(TTBAR, String)
    rest = txt[first(findfirst("[data_quality]", txt)):end]
    rest = replace(rest, "golden_json = \"Cert_Collisions2022_355100_362760_Golden.json\"" =>
                         "golden_json = \"" * joinpath(TTBAR_DIR, "Cert_Collisions2022_355100_362760_Golden.json") * "\"")
    rest = replace(rest, "[weights]\nmc = [\"genWeight\"]\ndata = []" =>
        "[weights]\nmc = [\"genWeight\"]\ndata = []\nvariations = [{ name = \"scale\", up = \"1.1\", down = \"0.9\" }]")
    head = """
    [analysis]
    name = "synthetic"
    lumi_pb = 100.0
    workdir = "work"
    [merge]
    yield_variable = "njet"
    [[samples]]
    name = "sigA"
    kind = "mc"
    xsec_pb = 2.0
    branching_ratio = 0.5
    format = "cols"
    files = ["$(dir)/sigA/*.cols"]
    [[samples]]
    name = "bkgB"
    kind = "mc"
    xsec_pb = 3.0
    format = "cols"
    files = ["$(dir)/bkgB/*.cols"]
    [[samples]]
    name = "dataEG"
    kind = "data"
    stream = "EGamma"
    format = "cols"
    files = ["$(dir)/dataEG/*.cols"]
    """
    body = head * "\n" * extra * "\n" * rest
    isempty(execution) || (body *= "\n[execution]\n" * execution * "\n")
    p = joinpath(dir, name)
    write(p, body)
    return p
end

function write_inputs(dir)
    rng = MersenneTwister(99)
    for (s, nf) in (("sigA", 3), ("bkgB", 2), ("dataEG", 2))
        for k in 1:nf
            cols = synthetic_events(rng, 3000)
            meta = s == "dataEG" ? Dict{String,Any}() : Dict{String,Any}("gen_weight_sum" => 1000.0 * k)
            write_column_file(joinpath(dir, s, "f$k.cols"), cols; meta)
        end
    end
end

"Content+metadata snapshot of every file below root (IO sentinel for read-only/unchanged)."
function snapshot(root)
    out = Dict{String,Any}()
    isdir(root) || return out
    for (d, _, names) in walkdir(root), n in names
        p = joinpath(d, n)
        out[relpath(p, root)] = (bytes2hex(open(sha256, p)), filesize(p), mtime(p))
    end
    return out
end

published_runs(work) = isdir(joinpath(work, "no-checkpoints")) ?
    sort([d for d in readdir(joinpath(work, "no-checkpoints")) if !startswith(d, ".")]) : String[]

is_final_rel(rel) = first(splitpath(rel)) in ("merge", "systematics", "fit", "plot") && !endswith(rel, ".meta.json")
is_image(rel) = any(ext -> endswith(rel, ext), (".png", ".pdf", ".svg", ".eps", ".root"))

const PNG_SIGNATURE = UInt8[0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]

"""
Image comparison used here (explicit criterion). Same relative inventory is asserted
by the callers; each pair must be non-empty with a valid PNG signature / %PDF header.
Byte identity is NOT asserted: the repository has no contract that native ROOT
PNG/PDF bytes are deterministic (existing validation docs check decoded/nonblank
PNGs and only OBSERVE byte identity). A pixel-level criterion is an open item for
the runtime gate (docs/NO_CHECKPOINTS.md, Verification).
"""
function check_image_pair(a, b)
    ba = read(a); bb = read(b)
    @test !isempty(ba) && !isempty(bb)
    if endswith(a, ".png")
        @test length(ba) >= 8 && ba[1:8] == PNG_SIGNATURE && length(bb) >= 8 && bb[1:8] == PNG_SIGNATURE
    elseif endswith(a, ".pdf")
        @test startswith(String(ba[1:min(5, end)]), "%PDF-") && startswith(String(bb[1:min(5, end)]), "%PDF-")
    end
    return ba == bb
end

const NFILES = 7
const MARKER = "execution.checkpoints=false cannot run this plan"
const NOTHING_RW = "nothing was read from or written"

caught(f) = try f(); nothing catch e; e end

"Assert that THE no-checkpoint admission check fired (common marker) with each specific reason."
function expect_admission(f, reasons...)
    err = caught(f)
    @test err isa ArgumentError
    msg = err === nothing ? "" : sprint(showerror, err)
    @test occursin(MARKER, msg)
    @test occursin(NOTHING_RW, msg)
    for r in reasons
        @test occursin(r, msg)
    end
    return msg
end

"Run f and restore the global hook registry to its prior state afterwards, even on error."
function with_hook_registry(f)
    saved = copy(HOOKS)
    try
        return f()
    finally
        empty!(HOOKS)
        merge!(HOOKS, saved)
    end
end

const AREA_SAVED_HOOKS = copy(HOOKS)
empty!(HOOKS)
try

@testset "execution.checkpoints option: strict Bool, default true, every profile" begin
    @test checkpoints_enabled(Dict())
    @test checkpoints_enabled(Dict("execution" => Dict()))
    @test checkpoints_enabled(Dict("execution" => Dict("checkpoints" => true)))
    @test !checkpoints_enabled(Dict("execution" => Dict("checkpoints" => false)))
    for bad in (1, 0, "false", "true", nothing, 1.0)
        @test_throws ArgumentError checkpoints_enabled(Dict("execution" => Dict("checkpoints" => bad)))
        @test_throws ArgumentError validate_keys(Dict("execution" => Dict("checkpoints" => bad)))
        @test_throws ArgumentError validate_keys(Dict("profiles" => Dict("inactive" => Dict("execution" => Dict("checkpoints" => bad)))))
    end
    @test validate_keys(Dict("execution" => Dict("checkpoints" => false))) isa AbstractDict
    # No shipped analysis/example/profile changes the default.
    tomls = String[]
    for (d, _, names) in walkdir(joinpath(ROOTDIR, "analyses")), n in names
        endswith(n, ".toml") && push!(tomls, joinpath(d, n))
    end
    for (d, _, names) in walkdir(joinpath(ROOTDIR, "examples")), n in names
        endswith(n, ".toml") && push!(tomls, joinpath(d, n))
    end
    @test !isempty(tomls)
    for p in tomls
        raw = TOML.parsefile(p)
        haskey(raw, "analysis") || continue
        @test checkpoints_enabled(resolve_config(raw))
        for prof in keys(get(raw, "profiles", Dict()))
            @test checkpoints_enabled(resolve_config(raw; profile = prof))
        end
    end
end

@testset "public constructors and CLI unchanged" begin
    @test fieldnames(RunOptions) == (:config, :profile, :steps, :samples, :force, :workdir, :max_files)
    o = RunOptions("a.toml")
    @test o.steps == STEPS && !o.force && o.max_files == 0 && isempty(o.samples)
    @test_throws ArgumentError parse_cli(["run", "a.toml", "--checkpoints", "false"])
    mktempdir() do dir
        write_inputs(dir)
        cfg = load_analysis(write_analysis(dir))
        ctx = StepContext(cfg, joinpath(dir, "w"), :select, cfg.samples, RunOptions("x"))
        @test ctx.input_scope === nothing
        @test checkpoints_enabled(cfg)
    end
end

@testset "checkpoints=true default path: per-file artifacts and cache contract unchanged" begin
    mktempdir() do dir
        write_inputs(dir)
        cfgp = write_analysis(dir)
        work = joinpath(dir, "work")
        sm = run_pipeline(RunOptions(cfgp; workdir = work))
        @test !haskey(sm, :checkpoints)
        @test sm[:select]["run"] == NFILES && sm[:histogram]["run"] == NFILES
        for step in ("select", "correct", "histogram")
            @test length([f for f in keys(snapshot(joinpath(work, step))) if endswith(f, ".meta.json")]) == NFILES
        end
        @test isfile(joinpath(work, "skim", "sigA.json.meta.json"))
        @test isfile(joinpath(work, "merge", "histograms.json.meta.json"))
        @test !ispath(joinpath(work, "no-checkpoints"))
        sm2 = run_pipeline(RunOptions(cfgp; workdir = work))
        @test all(v["run"] == 0 for v in values(sm2))
    end
end

@testset "checkpoints=false: fresh full chain, only final outputs, identical results" begin
    mktempdir() do dir
        write_inputs(dir)
        cfg_on = write_analysis(dir)
        cfg_off = write_analysis(dir; execution = "checkpoints = false", name = "off.toml")
        work_on = joinpath(dir, "work_on"); work_off = joinpath(dir, "work_off")
        run_pipeline(RunOptions(cfg_on; workdir = work_on))
        sm = run_pipeline(RunOptions(cfg_off; workdir = work_off))

        # Summary/provenance flags.
        ck = sm[:checkpoints]
        @test ck["enabled"] === false && ck["resume"] === false && ck["fresh_compute"] === true
        for step in STEPS
            @test sm[step]["skipped"] == 0
        end
        @test sm[:skim]["run"] == 3 && sm[:select]["run"] == NFILES && sm[:correct]["run"] == NFILES &&
              sm[:histogram]["run"] == NFILES && sm[:merge]["run"] == 1 && sm[:plot]["run"] == 1
        runs = published_runs(work_off)
        @test length(runs) == 1
        run = joinpath(work_off, "no-checkpoints", only(runs))
        @test ck["published_dir"] == run

        # Output inventory: nothing outside the published run directory, no per-file
        # artifacts, metadata sidecars, temporaries or hidden staging leftovers.
        all_off = snapshot(work_off)
        @test all(startswith(rel, joinpath("no-checkpoints", only(runs)) * "/") for rel in keys(all_off))
        rels = sort([relpath(joinpath(work_off, r), run) for r in keys(all_off)])
        @test PROV in rels
        @test !any(r -> first(splitpath(r)) in ("skim", "select", "correct", "histogram"), rels)
        @test !any(r -> endswith(r, ".meta.json") || occursin(".tmp", r) || r == "FAILED.json", rels)
        finals_on = sort([r for r in keys(snapshot(work_on)) if is_final_rel(r)])
        @test sort([r for r in rels if r != PROV]) == finals_on
        for r in ("merge/histograms.json", "merge/histograms_raw.json", "merge/samples.json", "merge/yields.tsv",
                  "merge/cutflow/sigA.tsv", "systematics/templates.json", "fit/result.json", "plot/index.json", "plot/yields.txt")
            @test r in rels
        end

        # Final products: exact bytes for every table/JSON/text output; plot/index.json
        # compared after normalising its path root; images by check_image_pair.
        for r in finals_on
            r == "plot/index.json" && continue
            if is_image(r)
                check_image_pair(joinpath(work_on, r), joinpath(run, r))
            else
                @test read(joinpath(work_on, r)) == read(joinpath(run, r))
            end
        end
        a = read_store(joinpath(work_on, "merge", "histograms.json")); b = read_store(joinpath(run, "merge", "histograms.json"))
        @test keys(a) == keys(b) && all(a[k] == b[k] for k in keys(a)) && a.meta == b.meta
        @test all(eltype(b[k].sumw) === Float64 for k in keys(b))
        idx_on = JSON3.read(read(joinpath(work_on, "plot", "index.json"), String))["files"]
        idx_off = JSON3.read(read(joinpath(run, "plot", "index.json"), String))["files"]
        @test [relpath(String(p), work_on) for p in idx_on] == [relpath(String(p), run) for p in idx_off]
        @test all(isfile(String(p)) && startswith(String(p), run * "/") for p in idx_off)

        # Provenance: explicit no-checkpoint/no-resume/fresh statement and exact inventory.
        prov = JSON3.read(read(joinpath(run, PROV), String))
        @test prov["checkpoints"] === false && prov["resume"] === false && prov["fresh_compute"] === true
        @test prov["per_file_checkpoint_reads"] == 0 && prov["per_file_checkpoint_writes"] == 0
        @test occursin("NOT measured", prov["per_file_checkpoint_io_basis"])
        @test occursin("main analysis TOML only", prov["config_sha256_scope"])
        @test prov["steps"] == String.(STEPS) && prov["published_dir"] == run
        @test prov["stages"]["select"]["run"] == NFILES && prov["stages"]["select"]["skipped"] == 0
        inv = prov["final_outputs"]
        @test sort(String.(collect(keys(inv)))) == sort([r for r in rels if r != PROV])
        for (r, d) in pairs(inv)
            @test d["sha256"] == bytes2hex(open(sha256, joinpath(run, String(r))))
        end
        @test prov["execution"]["max_claimed_unconsumed"] <= prov["execution"]["ordered_window"]
    end
end

@testset "dirty existing workdir: never read, modified, deleted or reused" begin
    mktempdir() do dir
        write_inputs(dir)
        cfg_on = write_analysis(dir)
        cfg_off = write_analysis(dir; execution = "checkpoints = false", name = "off.toml")
        work = joinpath(dir, "work")
        run_pipeline(RunOptions(cfg_on; workdir = work))
        reference = Dict(r => read(joinpath(work, r)) for r in keys(snapshot(work)) if is_final_rel(r))
        # Poison every payload the persisted route could reuse while keeping the
        # matching cache keys: any read/reuse would fail or change the results.
        for (d, _, names) in walkdir(work), n in names
            p = joinpath(d, n)
            endswith(n, ".meta.json") && continue
            write(p, "POISONED-CHECKPOINT")
        end
        before = snapshot(work)
        sm1 = run_pipeline(RunOptions(cfg_off; workdir = work))
        sm2 = run_pipeline(RunOptions(cfg_off; workdir = work))
        after = snapshot(work)
        for (rel, v) in before
            @test get(after, rel, nothing) == v           # unchanged and not deleted
        end
        new = [rel for rel in keys(after) if !haskey(before, rel)]
        @test all(startswith(rel, "no-checkpoints/") for rel in new)
        runs = published_runs(work)
        @test length(runs) == 2 && runs[1] != runs[2]   # second run did not reuse the first
        for sm in (sm1, sm2)
            @test sm[:select]["run"] == NFILES && sm[:histogram]["run"] == NFILES
        end
        for r in runs, (rel, bytes) in reference
            rel == "plot/index.json" && continue
            if is_image(rel)
                # reference bytes were poisoned above; compare against the second fresh run
                check_image_pair(joinpath(work, "no-checkpoints", runs[1], rel), joinpath(work, "no-checkpoints", runs[2], rel))
            else
                @test read(joinpath(work, "no-checkpoints", r, rel)) == bytes
            end
        end
    end
end

@testset "failure is atomic: nothing published, existing files untouched" begin
    mktempdir() do dir
        write_inputs(dir)
        # Valid for skim (event count, normalisation) but missing a selection input.
        c, _, _ = read_column_file(joinpath(dir, "bkgB", "f2.cols"))
        delete!(c, "Muon_pt")
        write_column_file(joinpath(dir, "bkgB", "f2.cols"), c; meta = Dict{String,Any}("gen_weight_sum" => 2000.0))
        cfg_off = write_analysis(dir; execution = "checkpoints = false", name = "off.toml")
        work = joinpath(dir, "work")
        mkpath(work); write(joinpath(work, "keep.txt"), "pre-existing")
        before = snapshot(work)
        err = caught(() -> run_pipeline(RunOptions(cfg_off; workdir = work)))
        @test err !== nothing
        @test !occursin(MARKER, sprint(showerror, err))   # a data-stage failure, not admission
        @test isempty(published_runs(work))
        after = snapshot(work)
        @test all(get(after, rel, nothing) == v for (rel, v) in before)
        hidden = isdir(joinpath(work, "no-checkpoints")) ? readdir(joinpath(work, "no-checkpoints")) : String[]
        @test all(h -> startswith(h, ".") && endswith(h, ".partial"), hidden)
        for h in hidden
            @test isfile(joinpath(work, "no-checkpoints", h, "FAILED.json"))
            @test !isfile(joinpath(work, "no-checkpoints", h, PROV))
        end
    end
end

@testset "bounded ordered window: order, retention bound, fail fast, no orphan workers" begin
    for window in (1, 2, 3, 8), workers in (1, 4)
        n = 40
        active = Threads.Atomic{Int}(0); peak = Threads.Atomic{Int}(0)
        f = function (k)
            a = Threads.atomic_add!(active, 1) + 1
            Threads.atomic_max!(peak, a)
            sleep(0.001 * ((k * 7) % 5))
            Threads.atomic_sub!(active, 1)
            return (k = k, sq = k * k)
        end
        w = OrderedWindow(f, collect(1:n); window, workers, label = "")
        got = try
            [take_next!(w) for _ in 1:n]
        finally
            shutdown_window!(w)
        end
        @test [r.k for r in got] == collect(1:n) && [r.sq for r in got] == (1:n) .^ 2
        @test w.max_retained <= window
        @test peak[] <= min(workers, window)
        @test window_completed(w)
        @test all(istaskdone, w.tasks)
    end
    claimed = Threads.Atomic{Int}(0)
    w = OrderedWindow(collect(1:100); window = 3, workers = 2) do k
        Threads.atomic_max!(claimed, k)
        k == 13 && error("injected failure 13")
        sleep(0.0005)
        k
    end
    err = try
        for _ in 1:100; take_next!(w); end
        nothing
    catch e
        e
    finally
        shutdown_window!(w)
    end
    @test err isa ErrorException && occursin("injected failure 13", sprint(showerror, err))
    @test claimed[] <= 13 + 3
    @test all(istaskdone, w.tasks) && !window_completed(w)
    # Consumer abandons early: shutdown wakes blocked workers, nothing leaks.
    w = OrderedWindow(k -> k, collect(1:50); window = 2, workers = 4)
    take_next!(w)
    shutdown_window!(w)
    @test all(istaskdone, w.tasks) && w.max_retained <= 2
    @test_throws ArgumentError OrderedWindow(identity, [1]; window = 0, workers = 1)
end

@testset "unsupported plans/features fail before any read or write" begin
    mktempdir() do dir
        write_inputs(dir)
        off = write_analysis(dir; execution = "checkpoints = false", name = "off.toml")
        bad_steps = [[:select, :correct, :histogram, :merge], [:skim, :select, :correct, :histogram],
                     [:merge], [:skim, :select, :correct, :histogram, :merge, :fit],
                     plan_steps(; from = "select"), plan_steps(; only = "plot"), Symbol[]]
        STEP_REASON = "steps must be one contiguous prefix"
        for steps in bad_steps
            work = joinpath(dir, "w_steps_" * join(String.(steps), "_"))
            expect_admission(() -> run_pipeline(RunOptions(off; workdir = work, steps)), STEP_REASON)
            @test !ispath(work)
        end
        # Programmatic plans longer than STEPS (duplicates; plan_steps would dedup):
        # aggregate admission error, never a BoundsError, and no writes.
        cfg_off = load_analysis(off)
        for (i, steps) in enumerate((vcat(STEPS, [:plot]), vcat(STEPS, STEPS), vcat(STEPS[1:5], STEPS[1:5])))
            @test length(steps) > length(STEPS)
            reasons = no_checkpoints_unsupported(cfg_off, cfg_off.samples, steps)
            @test any(r -> occursin(STEP_REASON, r), reasons)
            work = joinpath(dir, "w_dup$i")
            expect_admission(() -> run_pipeline(RunOptions(off; workdir = work, steps)), STEP_REASON)
            @test !ispath(work)
        end
        variants = [("memory_handoff = true", "execution.memory_handoff=true is a checkpoint-preserving mode"),
                    ("column_readers = 2", "execution.column_readers must be 1"),
                    ("decode_threads = 2", "execution.decode_threads must be 1"),
                    ("streaming_selection = true", "execution.streaming_selection must be false"),
                    ("event_range_selection = true", "execution.event_range_selection must be false")]
        for (i, (ex, reason)) in enumerate(variants)
            p = write_analysis(dir; execution = "checkpoints = false\n" * ex, name = "v$i.toml")
            work = joinpath(dir, "w_v$i")
            expect_admission(() -> run_pipeline(RunOptions(p; workdir = work)), reason)
            @test !ispath(work)
        end
        shape = """
        [[shape_variations]]
        name = "Scale"
        collection = "Jet"
        kind = "scale"
        fields = ["pt"]
        up = "1.02"
        down = "0.98"
        """
        theory = """
        [[theory_weights]]
        name = "muRmuF"
        family = "scale"
        branch = "LHEScaleWeight"
        samples = ["sigA"]
        expected_length = 9
        indices = [1, 2, 4, 6, 8, 9]
        normalization = "relative"
        reduction = "envelope"
        convention = "test only"
        """
        for (tag, extra, reason) in (("shape", shape, "active shape variations are not implemented"),
                                     ("theory", theory, "active theory weights are not implemented"))
            p = write_analysis(dir; execution = "checkpoints = false", extra, name = "$tag.toml")
            work = joinpath(dir, "w_$tag")
            expect_admission(() -> run_pipeline(RunOptions(p; workdir = work)), reason)
            @test !ispath(work)
        end
        before_hooks = copy(HOOKS)
        with_hook_registry() do
            register_hook!(:plot, (ctx, merged, fit) -> String[]; id = "custom")
            work = joinpath(dir, "w_hook")
            expect_admission(() -> run_pipeline(RunOptions(off; workdir = work)), "custom plot hook")
            @test !ispath(work)
            # The same hook is irrelevant when plot is not selected.
            ok = run_pipeline(RunOptions(off; workdir = work, steps = STEPS[1:5]))
            @test ok[:checkpoints]["enabled"] === false && !haskey(ok, :plot)
        end
        @test HOOKS == before_hooks
        # A dirty workdir is likewise untouched by a rejected plan.
        dirty = joinpath(dir, "dirty"); mkpath(joinpath(dirty, "select")); write(joinpath(dirty, "select", "x"), "old")
        before = snapshot(dirty)
        expect_admission(() -> run_pipeline(RunOptions(off; workdir = dirty, steps = [:merge])), STEP_REASON)
        @test snapshot(dirty) == before
    end
end

@testset "staged and batch APIs refuse checkpoints=false before writes" begin
    mktempdir() do dir
        write_inputs(dir)
        off = write_analysis(dir; execution = "checkpoints = false", name = "off.toml")
        cfg = load_analysis(off)
        w = joinpath(dir, "staged")
        for step in STEPS
            err = caught(() -> run_step(step, StepContext(cfg, w, step, cfg.samples, RunOptions(off; workdir = w))))
            @test err isa ArgumentError && occursin("execution.checkpoints=false: staged step $step", sprint(showerror, err))
        end
        @test !ispath(w)
        b = joinpath(dir, "batch")
        # On hosts whose temp path has symlink ancestry batch_safe_path rejects first;
        # either way nothing may be written.
        err = try batch_plan(RunOptions(off; workdir = b)); nothing catch e; e end
        @test err !== nothing
        if realpath(dir) == dir
            @test err isa ArgumentError && occursin("batch execution requires execution.checkpoints=true", sprint(showerror, err))
        end
        @test !ispath(b) && !ispath(b * ".plan.lock")
    end
end

@testset "samples subset and max_files match the checkpoint route" begin
    mktempdir() do dir
        write_inputs(dir)
        on = write_analysis(dir); off = write_analysis(dir; execution = "checkpoints = false", name = "off.toml")
        a = joinpath(dir, "a"); b = joinpath(dir, "b")
        steps = STEPS[1:5]
        run_pipeline(RunOptions(on; workdir = a, steps, samples = ["sigA", "dataEG"], max_files = 1))
        sm = run_pipeline(RunOptions(off; workdir = b, steps, samples = ["sigA", "dataEG"], max_files = 1))
        run = sm[:checkpoints]["published_dir"]
        for r in ("merge/histograms.json", "merge/histograms_raw.json", "merge/samples.json", "merge/yields.tsv")
            @test read(joinpath(a, r)) == read(joinpath(run, r))
        end
        prov = JSON3.read(read(joinpath(run, PROV), String))
        @test prov["files_per_sample"]["sigA"] == 1 && prov["max_files"] == 1
        @test !isdir(joinpath(run, "systematics")) && !isdir(joinpath(run, "plot"))
    end
end

@testset "region expressions, overlap provenance and default fit (admitted fit coverage)" begin
    mktempdir() do dir
        for sample in ("sig", "data")
            write_column_file(joinpath(dir, sample * ".cols"),
                Dict("Jet_pt" => Jagged([[0.5], [1.5], [2.5], [3.5]]), "genWeight" => ones(4));
                meta = Dict{String,Any}("gen_weight_sum" => 4.))
        end
        raw = Dict{String,Any}(
            "analysis" => Dict("name" => "categories", "lumi_pb" => 4.),
            "samples" => [Dict("name" => "sig", "kind" => "mc", "xsec_pb" => 1., "format" => "cols", "files" => [joinpath(dir, "sig.cols")]),
                          Dict("name" => "data", "kind" => "data", "format" => "cols", "files" => [joinpath(dir, "data.cols")])],
            "weights" => Dict("mc" => ["genWeight"]),
            "objects" => [Dict("name" => "jets", "collection" => "Jet", "cut" => "pt > 0")],
            "variables" => Dict("x" => "jets.pt[1]"),
            "cuts" => [Dict("name" => "one_jet", "expr" => "length(jets) == 1"),
                       Dict("name" => "positive", "expr" => "x > 0")],
            "regions" => [Dict("name" => "low", "after" => "positive", "expr" => "x < 2"),
                          Dict("name" => "high", "after" => "positive", "expr" => "x >= 2"),
                          Dict("name" => "inclusive", "after" => "positive")],
            "histograms" => [Dict("name" => "x", "edges" => [0., 5.], "values" => ["x"])],
            "fit" => Dict("signal" => ["sig"], "channels" => [Dict("name" => "low", "region" => "low", "variable" => "x"),
                                                                  Dict("name" => "high", "region" => "high", "variable" => "x")],
                          "staterror" => false, "histosys" => false, "impacts" => false, "profile_interval" => false))
        on = joinpath(dir, "on.toml"); open(io -> TOML.print(io, raw), on, "w")
        raw["execution"] = Dict("checkpoints" => false)
        off = joinpath(dir, "off.toml"); open(io -> TOML.print(io, raw), off, "w")
        steps = STEPS[1:7]
        a = joinpath(dir, "a"); b = joinpath(dir, "b")
        run_pipeline(RunOptions(on; workdir = a, steps))
        sm = run_pipeline(RunOptions(off; workdir = b, steps))
        run = sm[:checkpoints]["published_dir"]
        for r in ("merge/histograms.json", "merge/histograms_raw.json", "merge/samples.json", "merge/yields.tsv",
                  "systematics/templates.json")
            @test read(joinpath(a, r)) == read(joinpath(run, r))
        end
        store = read_store(joinpath(run, "merge", "histograms.json"))
        @test haskey(store.meta, "fit_channel_provenance")
        ra = JSON3.read(read(joinpath(a, "fit", "result.json"), String))
        rb = JSON3.read(read(joinpath(run, "fit", "result.json"), String))
        @test rb["status"] == ra["status"] == "ok" && rb["poi_value"] == ra["poi_value"]
        @test isfile(joinpath(run, "fit", "workspace.json"))
    end
end
finally
    empty!(HOOKS)
    merge!(HOOKS, AREA_SAVED_HOOKS)
end
end
