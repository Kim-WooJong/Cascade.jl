module TestSourceReuse
using Test, Cascade, TOML, JSON3
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Systematics, Cascade.Pipeline
include(joinpath(@__DIR__, "../systematics/weights/fixtures.jl"))
include(joinpath(@__DIR__, "../reduced/fixtures.jl"))
const P = Cascade.Pipeline
const I = Cascade.IO

mutable struct Counts
    opens::Int
    closes::Int
    masks::Vector{Vector{Bool}}
end
Counts() = Counts(0, 0, Vector{Bool}[])
struct CountingSource <: AbstractEventSource
    counts::Counts
end
I.nevents(::CountingSource) = 8
I.column_names(::CountingSource) = ["x", "vec"]
function I.read_columns(s::CountingSource, names; needed = nothing)
    push!(s.counts.masks, collect(needed))
    # Unrequested rows are deliberately invalid: caching a partial read across
    # shape/nominal masks would fail these tests.
    Dict{String,Any}(name => name == "x" ? [needed[e] ? Float64(e) : NaN for e in 1:8] :
        Jagged([needed[e] ? [Float64(e), -Float64(e)] : Float64[] for e in 1:8]) for name in names)
end
I.close_source(s::CountingSource) = (s.counts.closes += 1; nothing)
const SPEC = Dict{String,Any}("name"=>"T", "branch"=>"vec", "normalization"=>"relative", "indices"=>[1,2], "expected_length"=>2)

@testset "lazy source ownership and mask isolation" begin
    counts = Counts()
    register_source_format!("reuse_count", _ -> (counts.opens += 1; CountingSource(counts)))
    # Empty scalar reads skip source opening and branch/type diagnosis globally,
    # including the unborrowed compatibility fallback, not just lazy owners.
    fallback = BranchReader("reuse_count", "unused", Int[])
    try
        @test fallback("missing") isa Vector{Float64} && isempty(fallback("missing"))
        @test fallback("vec") isa Vector{Float64} && isempty(fallback("vec"))
        @test (counts.opens, counts.closes) == (0,0)
    finally
        close(fallback)
    end
    @test (counts.opens, counts.closes) == (0,0)
    subsets = [[6,2,6], [1,8], [4,3,4]]
    function compute(source)
        out = Any[]
        for entries in subsets
            r = BranchReader("reuse_count", "unused", entries; source)
            try
                push!(out, (r("x"), vector_members(r, SPEC)))
            finally
                close(r)
            end
        end
        out
    end
    old = compute(nothing)
    @test (counts.opens, counts.closes) == (3,3)
    counts.opens = counts.closes = 0; empty!(counts.masks)
    owner = LazyEventSource("reuse_count", "unused")
    @test counts.opens == 0
    @test isequal(compute(owner), old)
    @test (counts.opens, counts.closes) == (1,0)
    @test counts.masks[1] != counts.masks[3]
    close_source(owner); close_source(owner)
    @test (counts.opens, counts.closes) == (1,1)
    @test_throws ArgumentError nevents(owner)
    for entry in (Int[], [99], [1])
        owner = LazyEventSource("reuse_count", "unused")
        r = BranchReader("reuse_count", "unused", entry; source = owner)
        try
            if isempty(entry)
                @test isempty(r("missing"))
                @test all(isempty, vector_members(r, SPEC))
            elseif first(entry) == 99
                @test_throws ArgumentError r("x")
            else
                @test_throws ArgumentError r("missing")
            end
        finally
            close(r); close_source(owner)
        end
    end
    @test counts.opens == counts.closes == 3
    # Nonempty concurrent chunks acquire independent real sources, even when
    # they overlap rows; per-task counters avoid a test-side data race.
    threadcounts=[Counts() for _ in 1:6]
    for i in 1:6
        let c=threadcounts[i]
            register_source_format!("reuse_thread_$i", _ -> (c.opens+=1; CountingSource(c)))
        end
    end
    opened = run_tasks(collect(1:6)) do i
        s=LazyEventSource("reuse_thread_$i","unused")
        r=BranchReader("reuse_thread_$i","unused",[i,1,i];source=s)
        try
            @test r("x") == [Float64(i),1.,Float64(i)]
            yield()
            s.source
        finally
            close(r); close_source(s)
        end
    end
    @test length(unique(objectid.(opened))) == 6
    @test all(c->c.opens==c.closes==1,threadcounts)
    # Concurrent owners cannot share handles or validation state.
    owners = run_tasks(collect(1:6)) do _
        s = LazyEventSource("cols", "not-opened")
        yield()
        s
    end
    @test length(unique(objectid.(owners))) == 6
    @test all(s -> s.source === nothing, owners)
    foreach(close_source, owners)
    # An opener failure has no acquired source to close and is never trusted.
    failures=Ref(0)
    register_source_format!("reuse_fail", _ -> (failures[] += 1; error("open failed")))
    for _ in 1:2
        s=LazyEventSource("reuse_fail","unused")
        @test_throws ErrorException nevents(s)
        close_source(s)
    end
    @test failures[] == 2
end

@testset "correction/theory parity and no-source cases" begin
    mktempdir() do dir
        setpath = write_fixture_set(joinpath(dir,"fx.json"))
        pu = Dict{String,Any}("name"=>"pu", "set"=>"fx", "correction"=>"pu", "inputs"=>Dict("ntrue"=>"Pileup_nTrueInt"),
            "systematic"=>"which", "nominal"=>"nominal", "up"=>"up", "down"=>"down")
        cfg0 = fixture_config(Dict("event_weight"=>[pu]); setpath)
        raw = deepcopy(cfg0.raw)
        raw["theory_weights"] = [Dict("name"=>"ISR", "family"=>"ps", "branch"=>"PSWeight", "samples"=>["mc1"],
            "indices"=>[1,2], "expected_length"=>2, "normalization"=>"relative", "reduction"=>"pair", "convention"=>"synthetic")]
        cfg = parse_analysis(raw; dir)
        mc, data = cfg.samples
        path = write_fixture_source(joinpath(dir,"src.cols"))
        cols, meta, _ = read_column_file(path)
        cols["PSWeight"] = Jagged([[1. + i/100, 1. - i/100] for i in 1:12])
        write_column_file(path, cols; meta)
        tables = [fixture_table(n=3, entries=[6,2,6]), fixture_table(n=2, entries=[1,12]), fixture_table()]
        owner = P.correction_chunk_source(apply_corrections, mc, path)
        @test owner isa LazyEventSource
        for fail in (false,true)
            seen=Ref{Any}(nothing)
            invoke=() -> P.with_correction_source(apply_corrections,mc,path) do source
                seen[]=source
                apply_corrections(CorrectionContext(cfg,mc,path,fixture_table(),"nominal",source))
                fail && error("injected post-read failure")
                nothing
            end
            fail ? (@test_throws ErrorException invoke()) : invoke()
            @test seen[].closed && seen[].source === nothing
        end
        try
            for (i,t) in enumerate(tables)
                label = i == 3 ? "nominal" : "Shape$(i)Up"
                old = apply_corrections(CorrectionContext(cfg,mc,path,t,label))
                new = apply_corrections(CorrectionContext(cfg,mc,path,t,label,owner))
                @test all(reinterpret(UInt64,old[k]) == reinterpret(UInt64,new[k]) for k in keys(old))
                if label == "nominal"
                    old = theory_member_weights(cfg,mc,path,t,old)
                    new = theory_member_weights(cfg,mc,path,t,new; source=owner)
                    @test isequal(old,new)
                    @test !any(k -> occursin("Shape",k), keys(new))
                end
            end
        finally
            close_source(owner)
        end
        # Data, flat/table-only, object-only, empty scalar+theory: absent path is safe.
        missing = joinpath(dir,"absent.cols")
        for (c,s,t) in ((cfg,data,fixture_table()), (cfg,mc,fixture_table(n=0,entries=Int[])),
                        (fixture_config(Dict("flat"=>[Dict("name"=>"f","nominal"=>2.,"up"=>2.,"down"=>2.)]);setpath),mc,fixture_table()),
                        (fixture_config(Dict("object_sf"=>[Dict("name"=>"lep","set"=>"fx","correction"=>"lep_sf","object"=>"muons","indices"=>[1],"inputs"=>Dict("eta"=>"eta","pt"=>"pt"),"systematic"=>"syst","nominal"=>"nom")]);setpath),mc,fixture_table()))
            owner = P.correction_chunk_source(apply_corrections,s,missing)
            try
                w=apply_corrections(CorrectionContext(c,s,missing,t,"nominal",owner))
                theory_member_weights(c,s,missing,t,w;source=owner)
                @test owner.source === nothing
            finally
                close_source(owner)
            end
        end
        custom = ctx -> (@test ctx.source === nothing; apply_corrections(ctx))
        @test P.correction_chunk_source(custom,mc,path) === nothing
        custom(CorrectionContext(cfg,mc,path,fixture_table()))
        oldreader=I.SOURCE_FORMATS["cols"]
        try
            register_source_format!("cols", p->ColumnFileSource(p))
            @test P.correction_chunk_source(apply_corrections,mc,path) === nothing
        finally
            register_source_format!("cols",oldreader)
        end
    end
end

@testset "stage parity, cache and custom hook fallback" begin
    mktempdir() do dir
        p=ReducedFixtures.setup(dir)
        raw=TOML.parsefile(p)
        raw["hooks"]=Dict("correct"=>"Cascade.Systematics.apply_corrections")
        setpath=write_fixture_set(joinpath(dir,"fx.json"))
        raw["corrections"]=Dict("sets"=>Dict("fx"=>setpath),
            "event_weight"=>[Dict("name"=>"pu","set"=>"fx","correction"=>"pu","inputs"=>Dict("ntrue"=>"event * 0.0 + 20.0"),"systematic"=>"which","nominal"=>"nominal","up"=>"up","down"=>"down")],
            "flat"=>[Dict("name"=>"sf","nominal"=>2.,"up"=>2.2,"down"=>1.8)])
        ReducedFixtures.rewrite(p,raw)
        work=joinpath(dir,"new")
        run_pipeline(RunOptions(p;workdir=work,steps=ReducedFixtures.STEPS_REDUCED))
        # Source-independent custom wrapper forces the historical path, including
        # a separate theory BranchReader after nominal corrections.
        delete!(raw,"hooks"); ReducedFixtures.rewrite(p,raw)
        saved=copy(P.HOOKS)
        try
            register_hook!(:correct,ctx->(@test ctx.source === nothing; apply_corrections(ctx));id="old-style")
            old=joinpath(dir,"old")
            run_pipeline(RunOptions(p;workdir=old,steps=ReducedFixtures.STEPS_REDUCED))
            @test ReducedFixtures.compare_stores(joinpath(work,"merge/histograms.json"),joinpath(old,"merge/histograms.json"))
            for (root,_,files) in walkdir(joinpath(work,"correct")), f in files
                endswith(f,".cols") || continue
                a=joinpath(root,f); b=joinpath(old,relpath(a,work))
                @test read(a) == read(b)
            end
            cfg=load_analysis(p)
            result=run_step(:correct,StepContext(cfg,old,:correct,cfg.samples,RunOptions(p;workdir=old)))
            @test result == Dict("run"=>0,"skipped"=>1)
        finally
            empty!(P.HOOKS); merge!(P.HOOKS,saved)
        end
    end
end
end
