# Standalone stdlib-only semantic harness. No ROOT, Cascade load or dependencies.
# julia --startup-file=no test/node_memo/runtests.jl
using Test
module NodeMemoHarness
using Test
const ROOT = normpath(joinpath(@__DIR__, "../.."))
src(parts...) = joinpath(ROOT, "src", parts...)
for f in ("SampleConfig", "ObjectConfig", "CutConfig", "RegionConfig", "HistogramConfig",
          "VariationConfig", "TriggerConfig", "DataQualityConfig", "AnalysisConfig")
    include(src("Config", f * ".jl"))
end
include(src("IO", "Jagged.jl"))
abstract type AbstractEventSource end
struct FixtureSource <: AbstractEventSource
    raw::Dict{String,Any}
end
nevents(s::FixtureSource)=length(first(values(s.raw)))
function read_selection_columns(sel, s::FixtureSource; kwargs...)
    copy(s.raw),nothing
end
module Objects
function select_objects!(pred, buf::Vector{Int}, lo, hi)
    empty!(buf)
    for j in lo+1:hi
        pred(j) && push!(buf,j)
    end
    buf
end
function sort_objects!(buf, key; rev=true)
    sort!(buf; by=i->key[i], rev)
end
end
module Kernels
using ..Objects: select_objects!, sort_objects!
# Counting is deliberately typed: inference must not execute the function.
const COUNTS = zeros(Int, 16)
function mass_massless(x::T, tag::Int) where T
    COUNTS[tag] += 1
    return x
end
end
module EventIO
const Jagged = parentmodule(@__MODULE__).Jagged
end
for f in ("KernelContext", "ExpressionUsage", "VariableMemo", "CachedObjectBuffer",
          "parse_expression", "translate_expression", "compile_kernel", "Cutflow",
          "EventTable", "region_masks", "region_counts", "CompiledSelection",
          "SelectionProgress", "region_stages", "compile_selection", "apply_cuts",
          "event_loop", "prefix_pass", "selection_context", "staged_column_mask", "select_events", "run_selection_variations")
    include(src("Selection", f * ".jl"))
end

# Replace only physical IO. Production compiler, staged reader, masks, cached
# object spans, final loop and all-event ledger remain unmodified.
@eval EventIO begin
struct StreamWindowReader
    windows::Vector{UnitRange{Int}}
    pre::Vector{String}
    post::Vector{String}
    counters::Dict{String,String}
    options::NamedTuple{(:stream_window_bytes,),Tuple{Int}}
    diagnostics::Dict{String,Any}
    raw::Dict{String,Any}
    reads::Vector{Any}
end
function read_stream_branch(r, name, range; needed=nothing, offsets=nothing,
                            phase="pre", basket_observer=(_)->nothing)
    push!(r.reads,(name=name,mask=needed===nothing ? nothing : copy(needed),phase=phase))
    value=r.raw[name]
    H=parentmodule(@__MODULE__)
    if value isa H.Jagged
        lists=[collect(value[i]) for i in range]
        if needed!==nothing
            for i in eachindex(lists)
                needed[i] || fill!(lists[i],zero(eltype(value)))
            end
        end
        out=H.Jagged(lists)
        offsets===nothing || offsets==out.offsets || error("offset mismatch")
        return out
    end
    out=copy(value[range])
    if needed!==nothing
        for i in eachindex(out)
            needed[i] || (out[i]=zero(eltype(out)))
        end
    end
    return out
end
end
include(src("Selection","read_stream_selection_window.jl"))

function config(; enabled=true, cap=268435456, variables=Dict("mll"=>"mass_massless(Float32(x), 1)"),
                cuts=[CutConfig("mll", "mll > 0", :all)], objects=ObjectConfig[],
                outputs=["mll"], hist=[HistogramConfig("mll", [0.,100.], ["mll"], "true", String[], "mll")],
                variations=VariationConfig[], weights=String[])
    raw=Dict{String,Any}("execution"=>Dict("memoize_variables"=>enabled,"memoize_max_bytes"=>cap))
    AnalysisConfig("fixture","",ROOT,1.,SampleConfig[],objects,Dict{String,String}(variables),
        cuts,RegionConfig[],hist,weights,String[],variations,TriggerConfig(),DataQualityConfig(),outputs,"",raw)
end
node(sel,name) = only(n for n in sel.variable_nodes if n.name==name)
index(sel,name) = _node_index(node(sel,name).id)
function context(sel,raw,n)
    registry=VariableMemoRegistry(n,length(sel.variable_nodes),sel.memoize_max_bytes)
    ctx=selection_context(raw,sel,sel.collections; memo=registry,n)
    ctx,registry
end
call(f,args...) = Base.invokelatest(f,args...)
hitbytes(f::F,c,s) where F = @allocated _variable_value(f,c,1,s)
function compare_tables(a,b)
    @test a.order==b.order
    @test isequal(a.meta,b.meta)
    for name in a.order
        @test reinterpret(UInt8,a[name])==reinterpret(UInt8,b[name])
    end
end

@testset "staged cut -> later cut -> histogram/output evaluates mll once/event" begin
    cfg=config(cuts=[CutConfig("mass","mll > 0",:all),CutConfig("later","y > 0 && mll > 0",:all)],
        variables=Dict("mll"=>"mass_massless(Float32(x), 1)", "twice"=>"mll + mll"), outputs=["mll","twice"])
    sel=compile_selection(cfg,:mc)
    raw=Dict{String,Any}("x"=>Float32[1,2,3])
    p=SelectionProgress(sel,raw,3)
    fill!(Kernels.COUNTS,0)
    c=_progress_context(raw,sel,String[],p)
    @test Kernels.COUNTS[1]==0 # cold inference cannot execute a node
    call(advance_selection!,p,sel,c,1)
    @test Kernels.COUNTS[1]==3
    raw["y"]=[1,1,1]
    c=_progress_context(raw,sel,String[],p)
    call(advance_selection!,p,sel,c,2)
    @test Kernels.COUNTS[1]==3
    got,cf=select_events(sel,raw,3;progress=p)
    @test Kernels.COUNTS[1]==3
    @test eltype(p.memo.slots[index(sel,"mll")].values)===Float32
    @test all(p.memo.slots[index(sel,"mll")].valid)
    @test isempty(p.memo.diagnostics)
    offcfg=config(enabled=false,cuts=cfg.cuts,variables=cfg.variables,outputs=cfg.output_columns)
    off=compile_selection(offcfg,:mc)
    ref,refcf=select_events(off,raw,3)
    compare_tables(got,ref)
    @test isequal(cutflow_dict(cf),cutflow_dict(refcf))
    @test sel.columns_pre==off.columns_pre
    @test sel.columns_post==off.columns_post
    @test sel.column_stages==off.column_stages
    @test variable_memo_bytes(p.memo)>=p.memo.allocated_bytes>0
end

@testset "conservative prefix replay retains memo, weights reuse dependencies" begin
    obj=[ObjectConfig("jets","J","pt > 0",String[],.4,"")]
    s=compile_selection(config(objects=obj,weights=["mll"],
        cuts=[CutConfig("prefix","mll > 0",:all),CutConfig("objects","length(jets) > 0",:all)]),:mc)
    raw=Dict{String,Any}("x"=>Float32[1,2,3])
    p=SelectionProgress(s,raw,3)
    c=_progress_context(raw,s,String[],p)
    fill!(Kernels.COUNTS,0)
    mask=call(prefix_pass!,fill(false,3),s,c,3)
    @test all(mask) && Kernels.COUNTS[1]==3
    raw["J_pt"]=Jagged([[1.],[1.],[1.]])
    select_events(s,raw,3;progress=p)
    @test Kernels.COUNTS[1]==3
end

@testset "native types, rounding, NaN and transitive getter reuse" begin
    vars=Dict("integer"=>"mass_massless(Int(x),2)", "single"=>"mass_massless(Float32(x),3)",
        "native"=>"mass_massless(x,4)", "sum"=>"single + single", "nan"=>"mass_massless(NaN32,5)")
    sel=compile_selection(config(variables=vars,cuts=CutConfig[],outputs=collect(keys(vars)),hist=HistogramConfig[]),:mc)
    ctx,r=context(sel,Dict{String,Any}("x"=>[16777217]),1)
    fill!(Kernels.COUNTS,0)
    for name in sort!(collect(keys(vars)))
        n=node(sel,name);slot=r.slots[index(sel,name)]
        a=call(_variable_value,n.compute,ctx,1,slot)
        b=call(_variable_value,n.compute,ctx,1,slot)
        @test isequal(a,b)
        @test a isa (name=="integer" || name=="native" ? Int : Float32)
    end
    @test Kernels.COUNTS[2:5]==ones(Int,4)
    @test r.slots[index(sel,"single")].values[1]===Float32(16777217)
    @test isnan(r.slots[index(sel,"nan")].values[1])
    @test call(node(sel,"sum").compute,ctx,1) === Float32(16777217)+Float32(16777217)
end

@testset "guarded unsafe object index, when and masked-stage readiness" begin
    objects=[ObjectConfig("jets","J","pt > 0",String[],.4,"")]
    vars=Dict("unsafe"=>"mass_massless(jets.pt[2],6)")
    cuts=[CutConfig("guard","length(jets) < 2 || unsafe > 0",:all)]
    hist=[HistogramConfig("guarded",[0.,10.],["unsafe"],"length(jets) >= 2",String[],"")]
    sel=compile_selection(config(;variables=vars,cuts,objects,hist,outputs=String[]),:mc)
    raw=Dict{String,Any}("J_pt"=>Jagged([Float32[],Float32[1],Float32[1,2]]))
    fill!(Kernels.COUNTS,0)
    table,_=select_events(sel,raw,3)
    @test Kernels.COUNTS[6]==1
    @test isnan(table["h:guarded:1"][1]) && isnan(table["h:guarded:1"][2])
    # No early eager evaluation for if or && either.
    for expr in ("false && unsafe > 0", "true || unsafe > 0", "true ? true : unsafe > 0")
        s=compile_selection(config(;variables=vars,objects,cuts=[CutConfig("guard",expr,:all)],
            outputs=String[],hist=HistogramConfig[]),:mc)
        fill!(Kernels.COUNTS,0)
        select_events(s,raw,3)
        @test Kernels.COUNTS[6]==0
    end
    # Missing transitive input cannot allocate or validate its node; reading a
    # zero placeholder alone cannot trigger evaluation without a demand.
    late=compile_selection(config(variables=Dict("mll"=>"mass_massless(x + y,7)")),:mc)
    partial=Dict{String,Any}("x"=>[1.])
    p=SelectionProgress(late,partial,1)
    _progress_context(partial,late,String[],p)
    @test p.memo.slots[1]===nothing
    partial["y"]=[0.]
    _progress_context(partial,late,String[],p)
    @test !p.memo.slots[1].valid[1]
    # A failing getter does not commit validity.
    c,r=context(sel,raw,3)
    call(sel.materialize,c,1,0,typemax(Int))
    slot=r.slots[1]
    @test_throws BoundsError call(_variable_value,node(sel,"unsafe").compute,c,1,slot)
    @test !slot.valid[1]
end

@testset "shadowing, cycles and stable IDs" begin
    vars=Dict("x"=>"Float32(y)","mll"=>"x + x")
    a=compile_selection(config(variables=vars),:mc)
    b=compile_selection(config(variables=Dict(reverse(collect(vars)))),:mc)
    @test [typeof(n.id) for n in a.variable_nodes]==[typeof(n.id) for n in b.variable_nodes]
    t,_=select_events(a,Dict{String,Any}("x"=>[-1],"y"=>[3]),1)
    @test t["v:mll"]==[6.]
    for vars in (Dict("mll"=>"mll"),Dict("mll"=>"other","other"=>"mll"))
        @test_throws ArgumentError compile_selection(config(variables=vars),:mc)
    end
    # Object predicate bare fields do NOT resolve event variables of same name.
    obj=[ObjectConfig("jets","J","pt > 0",String[],.4,"")]
    s=compile_selection(config(variables=Dict("pt"=>"-100","mll"=>"length(jets)"),objects=obj),:mc)
    t,_=select_events(s,Dict{String,Any}("J_pt"=>Jagged([[1.]])),1)
    @test t["v:mll"]==[1.]
end

@testset "unsupported/overbudget cold fallback, no coercion" begin
    s=compile_selection(config(cap=1),:mc)
    ctx,r=context(s,Dict{String,Any}("x"=>[1.]),1)
    @test r.slots[1] isa UncachedVariable
    @test occursin("memoize_max_bytes",only(r.diagnostics).reason)
    @test r.allocated_bytes==0
    # Abstract/union source element types conservatively remain uncached.
    for x in (Any[1],Union{Int,Float32}[1])
        s=compile_selection(config(variables=Dict("mll"=>"x")),:mc)
        c,r=context(s,Dict{String,Any}("x"=>x),1)
        @test r.slots[1] isa UncachedVariable
        @test !isempty(r.diagnostics)
        @test call(node(s,"mll").compute,c,1)===1
    end
end

@testset "empty, independent concurrent contexts and variation isolation" begin
    s=compile_selection(config(),:mc)
    empty,_=select_events(s,Dict{String,Any}("x"=>Float32[]),0)
    @test isempty(empty["entry"])
    a,ra=context(s,Dict{String,Any}("x"=>Float32[1]),1)
    b,rb=context(s,Dict{String,Any}("x"=>Float32[9]),1)
    tasks=[(@async call(s.outputs,a,1,1)), (@async call(s.outputs,b,1,1))]
    @test fetch(tasks[1])==(1.,1.)
    @test fetch(tasks[2])==(9.,9.)
    @test ra.slots[1] !== rb.slots[1]
    for value in (1f0,9f0,1f0)
        t,_=select_events(s,Dict{String,Any}("x"=>[value]),1)
        @test t["v:mll"]==[Float64(value)]
    end
    source=FixtureSource(Dict{String,Any}("x"=>Float32[2]))
    vary=(raw,needed)->["nominal"=>Dict{String,Any}("x"=>Float32[3]),
        "shift"=>Dict{String,Any}("x"=>Float32[7])]
    fill!(Kernels.COUNTS,0)
    results=run_selection_variations(s,source,vary;replaces=["x"])
    @test results[1].second[1]["v:mll"]==[3.]
    @test results[2].second[1]["v:mll"]==[7.]
    @test Kernels.COUNTS[1]==2
    cfg=config(variations=[VariationConfig("shape","mll","mll + 1")])
    s=compile_selection(cfg,:mc)
    t,_=select_events(s,Dict{String,Any}("x"=>Float32[4]),1)
    @test t["w:shapeUp"]==[4.] && t["w:shapeDown"]==[5.]
end

@testset "old constructors and concrete hot getter" begin
    s=compile_selection(config(enabled=false),:mc)
    args=(s.kind,s.cut_names,s.cuts,s.mat_at,s.materialize,s.weight,s.outputs,
        s.output_names,s.hist_columns,s.object_names,s.collections,s.columns_pre,s.columns_post,
        s.builtins,s.region_stage,s.keep_stage,s.triggers,s.data_quality)
    @test isempty(CompiledSelection(args...).variable_nodes)
    @test isempty(CompiledSelection(args...,s.column_stages).variable_nodes)
    @test KernelContext((x=[1],),NamedTuple(),NamedTuple()).memo===nothing
    ctx=KernelContext((x=[1f0],),NamedTuple(),NamedTuple())
    slot=VariableMemoColumn(Float32[0],Bool[false])
    f=(c,i)->c.cols.x[i]
    @test @inferred(_variable_value(f,ctx,1,slot))===1f0
    @test @inferred(_variable_value(f,ctx,1,slot))===1f0
    hitbytes(f,ctx,slot) # warm allocation wrapper
    @test hitbytes(f,ctx,slot)==0
end

@testset "actual compiler -> masked staged window -> all-event ledger" begin
    objects=[ObjectConfig("jets","J","pt > 0",String[],.4,"")]
    vars=Dict("mll"=>"mass_massless(jets.pt[1],8)")
    cuts=[CutConfig("prefix","x > 0",:all),CutConfig("objects","length(jets) > 0",:all),
          CutConfig("mass","mll > 20",:all),CutConfig("later","y > 0 && mll > 20",:all)]
    cfg=config(;variables=vars,objects,cuts,outputs=["mll","z"],weights=["genWeight"])
    sel=compile_selection(cfg,:mc)
    raw=Dict{String,Any}("x"=>[-1,1,2,3,4],"y"=>[1,1,-1,1,1],"z"=>[1.,2.,3.,4.,5.],
        "genWeight"=>[1e16,1.,-1e16,3.,-2.],"nJ"=>[1,0,1,1,1],
        "J_pt"=>Jagged([Float32[99],Float32[],Float32[30],Float32[40],Float32[50]]))
    reader=EventIO.StreamWindowReader([1:5],sel.columns_pre,sel.columns_post,Dict("J_pt"=>"nJ"),
        (stream_window_bytes=64*1024^2,),
        Dict{String,Any}("prefix_events"=>0,"prefix_pass"=>0,"max_raw_window_bytes"=>0),raw,Any[])
    # Both options at their default budgets: tiny ranges reserve only possible
    # memo storage, not the 256 MiB cap against a 64 MiB window.
    reserve=variable_memo_reservation(sel,5)
    @test 0 < reserve < reader.options.stream_window_bytes < sel.memoize_max_bytes
    fill!(Kernels.COUNTS,0)
    payload=read_incremental_selection_window(reader,sel,1)
    @test Kernels.COUNTS[8]==3
    @test payload.raw["J_pt"].content[1]==0f0 # masked placeholder, never memoized
    @test !payload.progress.memo.slots[index(sel,"mll")].valid[1]
    @test !payload.progress.memo.slots[index(sel,"mll")].valid[2]
    @test only(r for r in reader.reads if r.name=="J_pt").mask==[false,true,true,true,true]
    @test only(r for r in reader.reads if r.name=="z").mask==[false,false,false,true,true]
    stages=fill(-1,5);weights=fill(NaN,5)
    got,cf=select_events(sel,payload.raw,5;progress=payload.progress,
        all_event_stage=stages,all_event_weight=weights)
    @test Kernels.COUNTS[8]==3 # cut -> later cut -> persisted outputs/hist, no replay
    @test stages==[0,1,3,4,4]
    @test weights==raw["genWeight"]
    @test got["entry"]==[4,5]
    @test variable_memo_bytes(payload.progress.memo)<=reserve
    @test incremental_window_bytes(payload.raw,payload.progress)<=reader.options.stream_window_bytes
    off=compile_selection(config(;enabled=false,variables=vars,objects,cuts,
        outputs=["mll","z"],weights=["genWeight"]),:mc)
    refstage=zeros(Int,5);refweight=zeros(5)
    ref,refcf=select_events(off,raw,5;all_event_stage=refstage,all_event_weight=refweight)
    compare_tables(got,ref)
    @test stages==refstage
    @test reinterpret(UInt64,weights)==reinterpret(UInt64,refweight)
    @test isequal(cutflow_dict(cf),cutflow_dict(refcf))
    # Ledger-only worker mode also preserves every rejected event.
    s2=zeros(Int,5);w2=zeros(5)
    _,worker_cf=select_events(sel,payload.raw,5;progress=payload.progress,
        all_event_stage=s2,all_event_weight=w2,record_cutflow=false)
    @test s2==stages && w2==weights
    @test all(iszero,worker_cf.n)
end

# Enter generated functions in their world with concrete function/context types.
function check_compiled_native(f::F, ctx, expected) where F
    @test @inferred(f(ctx,1)) === expected
    f(ctx,1)
    @test (@allocated f(ctx,1))==0
end
function check_compiled_outputs(f::F, ctx, expected) where F
    @test @inferred(f(ctx,1,0)) === expected
    f(ctx,1,0)
    @test (@allocated f(ctx,1,0))==0
end
@testset "actual transitive compiled demand getter inference and warmed allocation" begin
    vars=Dict("a"=>"mass_massless(Float32(x),9)","b"=>"a + a","c"=>"b + b")
    sel=compile_selection(config(variables=vars,cuts=CutConfig[],outputs=["c"],hist=HistogramConfig[]),:mc)
    ctx,r=context(sel,Dict{String,Any}("x"=>Float32[3]),1)
    fill!(Kernels.COUNTS,0)
    call(check_compiled_native,node(sel,"c").compute,ctx,12f0)
    call(check_compiled_outputs,sel.outputs,ctx,(12.,))
    @test Kernels.COUNTS[9]==1
    @test all(slot->slot isa VariableMemoColumn{Float32},r.slots)
end

@testset "metadata-only memo reservation bounds actual owned capacities" begin
    @test VARIABLE_MEMO_MAX_VALUE_BYTES==16
    @test maximum(sizeof,VARIABLE_MEMO_TYPES)==VARIABLE_MEMO_MAX_VALUE_BYTES
    for cap in (1,128,4096,268435456)
        sel=compile_selection(config(cap=cap,variables=Dict("mll"=>"x")),:mc)
        for n in (0,1,17,1024)
            reservation=variable_memo_reservation(sel,n)
            @test reservation isa Int128
            registry=VariableMemoRegistry(n,1,cap)
            @test variable_memo_bytes(registry)<=reservation
            for T in VARIABLE_MEMO_TYPES
                values=fill(one(T),n)
                c,r=context(sel,Dict{String,Any}("x"=>values),n)
                @test variable_memo_bytes(r)<=reservation
                @test r.allocated_bytes<=cap
                @test length(r.diagnostics)<=1
                @test all(d->ncodeunits(d.reason)<=VARIABLE_MEMO_REASON_BYTES,r.diagnostics)
            end
            for values in (Any[1 for _ in 1:n],Union{Int,Float32}[1 for _ in 1:n])
                c,r=context(sel,Dict{String,Any}("x"=>values),n)
                @test r.slots[1] isa UncachedVariable
                @test variable_memo_bytes(r)<=reservation
                @test length(r.diagnostics)==1
                # Duplicate reporting cannot allocate another diagnostic.
                _memo_fallback!(r,node(sel,"mll"),VARIABLE_MEMO_TYPE_REASON)
                @test length(r.diagnostics)==1
            end
        end
    end
    # Long names are charged explicitly, not hidden behind a fixed metadata fee.
    longname=repeat("named_variable_",100)
    vars=Dict(longname=>"x","mll"=>longname)
    sel=compile_selection(config(cap=1,variables=vars),:mc)
    c,r=context(sel,Dict{String,Any}("x"=>[1]),1)
    @test variable_memo_bytes(r)<=variable_memo_reservation(sel,1)
    @test length(r.diagnostics)==2
    # Every byte of the fixed diagnostic backing store is part of measurement.
    @test length(r.diagnostics.storage)==length(sel.variable_nodes)
    disabled=compile_selection(config(enabled=false),:mc)
    nonodes=compile_selection(config(variables=Dict{String,String}(),outputs=String[],
        cuts=CutConfig[],hist=HistogramConfig[]),:mc)
    @test variable_memo_reservation(disabled,100)==0
    @test variable_memo_reservation(nonodes,100)==0
    @test_throws ArgumentError variable_memo_reservation(sel,-1)
    @test variable_memo_reservation(sel,typemax(Int))>0 # overflow-safe Int128 bound
end
end # module
