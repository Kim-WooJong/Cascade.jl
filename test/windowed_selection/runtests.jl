# Standalone: stdlib only, no Cascade load, ROOT input or package precompile.
using Test
module WindowedHarness
using Test
const ROOT = normpath(joinpath(@__DIR__, "../.."))
src(parts...) = joinpath(ROOT, "src", parts...)
struct AnalysisConfig
    raw::Dict{String,Any}
    variations::Vector{Any}
end
AnalysisConfig(raw) = AnalysisConfig(Dict{String,Any}(raw), Any[])
for file in ("TriggerConfig", "DataQualityConfig", "column_readers", "decode_options",
             "windowed_selection", "memory_handoff", "streaming_selection_options", "memoization_options", "checkpoint_options", "event_ranges", "validate_keys")
    include(src("Config", file * ".jl"))
end
include(src("IO", "Jagged.jl"))
module Objects
function select_objects!(pred, buf::Vector{Int}, lo, hi)
    empty!(buf)
    for j in lo+1:hi
        pred(j) && push!(buf, j)
    end
    buf
end
function sort_objects! end
end
module EventIO
const Jagged = parentmodule(@__MODULE__).Jagged
# Only replace the physical IO boundary. All progress/selection code is real.
struct StreamWindowReader
    windows::Vector{UnitRange{Int}}
    pre::Vector{String}
    post::Vector{String}
    counters::Dict{String,String}
    options::Any
    diagnostics::Dict{String,Any}
    raw::Dict{String,Any}
    reads::Vector{Any}
end
function read_stream_branch(reader, name, range; needed=nothing, offsets=nothing, phase="pre", basket_observer=(_)->nothing)
    push!(reader.reads, (name=name, range=range, mask=needed===nothing ? nothing : copy(needed), offsets=offsets))
    value = reader.raw[name]
    if hasproperty(value, :offsets)
        # Canonical flat indices including placeholders for masked events.
        n = length(range)
        lists = [collect(value[i]) for i in range]
        if needed !== nothing
            for i in 1:n
                needed[i] || fill!(lists[i], 0.0)
            end
        end
        out = parentmodule(@__MODULE__).Jagged(lists)
        offsets === nothing || out.offsets == offsets || error("counter disagreement")
        return out
    end
    out = copy(value[range])
    if needed !== nothing
        for i in eachindex(out)
            needed[i] || (out[i]=zero(eltype(out)))
        end
    end
    return out
end
end
for file in ("KernelContext", "CachedObjectBuffer", "ExpressionUsage", "VariableMemo", "Cutflow", "EventTable", "region_masks", "region_counts", "CompiledSelection", "SelectionProgress", "apply_cuts", "event_loop", "prefix_pass", "selection_context", "staged_column_mask", "select_events", "read_stream_selection_window")
    include(src("Selection", file * ".jl"))
end
const Selection = @__MODULE__
struct StreamFileError <: Exception end
const HOOKS=Dict{Symbol,Any}()
builtin_source_readers() = true
shape_variations(cfg) = get(cfg.raw,"shape_variations",Any[])
theory_weights(cfg) = get(cfg.raw,"theory_weights",Any[])
include(src("Pipeline", "stream_selection.jl"))

function reader(sel,raw,ranges)
    EventIO.StreamWindowReader(collect(ranges), sel.columns_pre, sel.columns_post,
        Dict(name=>"nJ" for name in sel.columns_post if startswith(name,"J_")),
        (stream_window_bytes=10^7,stream_retained_bytes=10^7),
        Dict{String,Any}("prefix_events"=>0,"prefix_pass"=>0,"max_raw_window_bytes"=>0),raw,Any[])
end
function compare(sel,raw,ranges; expected_entries=nothing)
    n=length(raw["w"])
    reference, cf=select_events(sel,raw,n;sample="fixture")
    a=StreamSelectionAnalysis(sel,"fixture")
    r=reader(sel,raw,ranges)
    for k in eachindex(r.windows)
        analyze_incremental_selection_window!(a,r,sel,k;stream="",lumimask=nothing)
    end
    got=finish_stream_selection!(a,n;validate=true)
    @test got.order==reference.order
    @test isequal(got.meta,reference.meta)
    for key in reference.order
        @test reinterpret(UInt8,got[key])==reinterpret(UInt8,reference[key])
    end
    for key in ("sumw","sumw2")
        @test reinterpret(UInt64,cutflow_dict(a.cutflow)[key])==reinterpret(UInt64,cutflow_dict(cf)[key])
    end
    @test a.cutflow.n==cf.n
    expected_entries===nothing || @test got["entry"]==expected_entries
    return r,a
end
function scalar_selection(; stages=true, nocuts=false)
    cuts=nocuts ? () : ((c,i)->c.cols.x[i]>0, (c,i)->c.cols.y[i]>0)
    CompiledSelection(:mc,nocuts ? String[] : ["x","y"],cuts,0,(c,i,l,h)->nothing,
        (c,i)->c.cols.w[i],(c,i,s)->(c.cols.z[i],1.0),["z","r:early"],
        Dict{String,Vector{String}}(),String[],String[],["w","x"],["y","z"],String[],
        Dict("early"=>(nocuts ? 0 : 1)),nocuts ? 0 : 1,TriggerConfig(),DataQualityConfig(),
        stages ? Dict("y"=>2,"z"=>typemax(Int)) : Dict{String,Int}())
end
@testset "strict Bool independent defaults and inactive profiles" begin
    @test !windowed_selection(Dict())
    @test !memory_handoff(Dict("execution"=>Dict("windowed_selection"=>true)))
    @test windowed_selection(Dict("execution"=>Dict("windowed_selection"=>true)))
    for value in (1,0,"true",nothing,1.0)
        @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("windowed_selection"=>value)))
        @test_throws ArgumentError validate_keys(Dict("profiles"=>Dict("inactive"=>Dict("execution"=>Dict("windowed_selection"=>value)))))
    end
    for engine in (Dict("streaming_selection"=>true),Dict("decode_threads"=>2),Dict("decode_threads"=>"auto"),Dict("column_readers"=>2))
        raw=Dict("execution"=>merge(Dict{String,Any}("windowed_selection"=>true),engine))
        @test validate_keys(raw)===raw
        cfg=AnalysisConfig(raw)
        reason=windowed_selection_fallback(cfg,(format="nanoaod",),nothing)
        @test reason in ("streaming_selection_enabled","decode_threads_not_one","column_readers_not_one")
        @test streaming_selection_options(raw).enabled == get(engine,"streaming_selection",false)
    end
    cfg=AnalysisConfig(Dict("execution"=>Dict("windowed_selection"=>true)))
    @test windowed_selection_fallback(cfg,(format="nanoaod",),nothing)==""
    @test windowed_selection_fallback(cfg,(format="cols",),nothing)=="unsupported_format"
    @test windowed_selection_fallback(cfg,(format="nanoaod",),:shape)=="shape_variations"
    push!(HOOKS,:correct=>nothing)
    @test windowed_selection_fallback(cfg,(format="nanoaod",),nothing)=="custom_hooks"
    empty!(HOOKS)
end
@testset "split vs whole ordered bitpatterns; no objects, no cuts, empty, fallback" begin
    raw=Dict{String,Any}("w"=>[1e16,1.,-1e16,3.,-2.],"x"=>[1.,1.,1.,-1.,1.],
        "y"=>[-1.,1.,1.,1.,-1.],"z"=>[11.,12.,13.,14.,15.])
    for sel in (scalar_selection(),scalar_selection(stages=false),scalar_selection(nocuts=true))
        compare(sel,raw,[1:1,2:3,4:5])
        compare(sel,raw,[1:5])
        compare(sel,Dict{String,Any}(k=>v[1:0] for (k,v) in raw),[1:0])
    end
    r,a=compare(scalar_selection(),raw,[1:5];expected_entries=[1,2,3,5])
    @test a.cutflow.sumw[1]==1.0
    @test only(x for x in r.reads if x.name=="z").mask==[true,true,true,false,true]
    @test !any(v isa EventIO.StreamWindowReader for v in (getfield(a,k) for k in fieldnames(typeof(a))))
end

# A real CachedObjectBuffer fixture: the first event is retained after a later
# failure, while following events build output-only spans before it is finished.
function object_selection(calls)
    materialize=(ctx,i,lo,hi)->begin
        if lo<2<=hi
            Objects.select_objects!(j->ctx.cols.J_pt[j]>0,ctx.objs.j,ctx.offs.J[i],ctx.offs.J[i+1])
        end
        if lo<typemax(Int)<=hi
            Objects.select_objects!(j->ctx.cols.K_pt[j]>0,ctx.objs.k,ctx.offs.K[i],ctx.offs.K[i+1])
        end
        nothing
    end
    cuts=((c,i)->(calls[1]+=1;c.cols.x[i]>0),
          (c,i)->(calls[2]+=1;length(c.objs.j)>=1),
          (c,i)->(calls[3]+=1;c.cols.J_eta[first(c.objs.j)]>0))
    outputs=(c,i,s)->(sum(c.cols.J_pt[j] for j in c.objs.j;init=0.0),
        sum(c.cols.K_pt[j] for j in c.objs.k;init=0.0),1.0)
    CompiledSelection(:mc,["prefix","objects","late"],cuts,2,materialize,(c,i)->c.cols.w[i],outputs,
        ["j","k","r:early"],Dict{String,Vector{String}}(),["j","k"],["J","K"],
        ["w","x"],["J_pt","J_eta","K_pt"],String[],Dict("early"=>1),1,TriggerConfig(),DataQualityConfig(),
        Dict("J_pt"=>2,"J_eta"=>3,"K_pt"=>typemax(Int)))
end
@testset "early retained failure, output-only objects, stale spans and counters" begin
    raw=Dict{String,Any}("w"=>[1e16,1.,-1e16,3.,-2.],"x"=>[1.,1.,-1.,1.,1.],
        "nJ"=>[1,0,1,1,1],"nK"=>[1,1,1,1,0],
        "J_pt"=>Jagged([[11.],Float64[],[33.],[44.],[55.]]),
        "J_eta"=>Jagged([[-1.],Float64[],[1.],[1.],[1.]]),
        "K_pt"=>Jagged([[101.],[102.],[103.],[104.],Float64[]]))
    calls=zeros(Int,3);sel=object_selection(calls)
    # K also needs canonical offsets, separately from J.
    r=reader(sel,raw,[1:2,3:5]);r.counters["K_pt"]="nK"
    ref,cf=select_events(sel,raw,5;sample="fixture")
    fill!(calls,0)
    a=StreamSelectionAnalysis(sel,"fixture")
    for k in eachindex(r.windows)
        analyze_incremental_selection_window!(a,r,sel,k;stream="",lumimask=nothing)
    end
    got=finish_stream_selection!(a,5;validate=true)
    @test calls==[5,4,3] # no replay of ordinary prefix or object cuts
    @test got["entry"]==[1,2,4,5]
    @test got["j"]==[11.,0.,44.,55.]
    @test got["k"]==[101.,102.,104.,0.]
    @test isequal(got.meta,ref.meta)
    @test all(reinterpret(UInt8,got[key])==reinterpret(UInt8,ref[key]) for key in ref.order)
    @test all(reinterpret(UInt64,getfield(a.cutflow,key))==reinterpret(UInt64,getfield(cf,key)) for key in (:sumw,:sumw2))
    @test count(x->x.name=="nJ",r.reads)==2 # once/window, not once/column
    @test count(x->x.name=="nK",r.reads)==2
    @test only(x for x in r.reads if x.name=="J_pt" && x.range==3:5).mask==[false,true,true]
end
@testset "publication validation" begin
    sel=scalar_selection();raw=Dict{String,Any}("w"=>[1.],"x"=>[1.],"y"=>[1.],"z"=>[1.])
    r,a=compare(sel,raw,[1:1])
    @test_throws ErrorException finish_stream_selection!(a,2;validate=true)
    a.table["entry"][1]=2
    @test_throws ErrorException finish_stream_selection!(a,1;validate=true)
end
# Only metadata descriptors are used; no physical reader is available here.
@eval EventIO stream_basket_overlap(baskets, range) = findall(bs->bs.lo<=last(range) && bs.hi>=first(range),baskets)
function metadata_reader(n, branches; budget=64*1024^2)
    (windows=[1:n],branches=branches,options=(stream_window_bytes=budget,))
end
function metadata_branch(n, bytes; E=Float32,jagged=false)
    (E=E,jagged=jagged,baskets=n==0 ? NamedTuple[] : [(lo=1,hi=n,decoded=bytes)])
end
@testset "metadata-only tight sound reservations before reads" begin
    n=20_000;empty_sel=(object_names=String[],)
    flat=Dict{String,Any}("f$i"=>metadata_branch(n,4n) for i in 1:20)
    r=metadata_reader(n,flat)
    res,reason=windowed_selection_reservation(r,empty_sel,1:n,nothing)
    expected=20*4n+16n*20+4n+17n+cld(n,8)+4096*21
    @test reason==""
    @test res.required_bytes==expected
    @test expected<64*1024^2
    @test reserve_windowed_selection(r,empty_sel,nothing)==(expected,"")
    @test expected < 16*(20*4n)+64n*21 < 64*1024^2 # 20 fields fit both; old charge is still excessive
    branches=copy(flat)
    branches["J_pt"]=metadata_branch(n,4n*3;jagged=true)
    branches["J_eta"]=metadata_branch(n,8n*4;E=Float64,jagged=true)
    branches["J_tag"]=metadata_branch(n,n*5;E=UInt8,jagged=true)
    sel=(object_names=["j$i" for i in 1:5],)
    mapping=[name=>"J" for name in sel.object_names]
    rj=metadata_reader(n,branches)
    jr,jreason=windowed_selection_reservation(rj,sel,1:n,mapping)
    @test jreason==""
    @test jr.object_element_bound==5*3n # min(3n,4n,5n), EACH category
    @test jr.required_bytes<64*1024^2
    @test last(reserve_windowed_selection(rj,sel,mapping))==""
    one=(object_names=["j"],)
    j1,_=windowed_selection_reservation(rj,one,1:n,["j"=>"J"])
    @test jr.required_bytes-j1.required_bytes==4*(16n+16*3n+4096)
    byteonly=metadata_reader(n,Dict("J_flag"=>metadata_branch(n,123456;E=UInt8,jagged=true)))
    byteres,_=windowed_selection_reservation(byteonly,one,1:n,["j"=>"J"])
    @test byteres.object_element_bound==123456
    @test last(windowed_selection_reservation(r,one,1:n,nothing))=="object_collection_mapping_missing"
    @test last(reserve_windowed_selection(r,one,["j"=>"J"]))=="object_collection_bound_unavailable:J"
    @test last(reserve_windowed_selection(rj,one,["wrong"=>"J"]))=="object_collection_mapping_mismatch"
    incompatible=metadata_reader(n,Dict("J_bad"=>metadata_branch(n,100;E=String,jagged=true)))
    @test last(reserve_windowed_selection(incompatible,one,["j"=>"J"]))=="object_collection_bound_unavailable:J"
    er=metadata_reader(0,Dict{String,Any}())
    @test reserve_windowed_selection(er,empty_sel,nothing)==(4096,"")
    small=metadata_reader(n,flat;budget=1)
    err=try reserve_windowed_selection(small,empty_sel,nothing);nothing catch e;e end
    @test err isa ErrorException
    message=sprint(showerror,err)
    @test occursin("window_index=1",message)
    @test occursin("required_bytes=$expected",message)
    @test occursin("execution.stream_window_bytes=1",message)
    @test_throws OverflowError _window_mul(typemax(Int128),2)
    malformed=metadata_reader(n,Dict("bad"=>metadata_branch(n,-1)))
    @test_throws ErrorException reserve_windowed_selection(malformed,empty_sel,nothing)
end
end # harness

@testset "memo does not enter unbudgeted legacy async analysis" begin
    cfg = WindowedHarness.AnalysisConfig(Dict("execution"=>Dict("memoize_variables"=>true,"streaming_selection"=>true)))
    @test WindowedHarness.stream_selection_fallback(cfg,(format="nanoaod",),nothing)=="memoize_variables_requires_incremental_owner"
    @test WindowedHarness.open_stream_selection(nothing,(variable_nodes=(1,),),nothing,nothing)=="memoize_variables_requires_incremental_owner"
end

@testset "serial memo admission includes late slots before any reader exists" begin
    W = WindowedHarness
    n = 2
    sel = (object_names=String[],variable_nodes=((name="late",),),memoize_max_bytes=268435456)
    branches = Dict("x"=>W.metadata_branch(n,4n))
    r = W.metadata_reader(n,branches)
    base,reason = W.windowed_selection_reservation(r,sel,1:n,nothing)
    memo = W.variable_memo_reservation(sel,n)
    @test reason == "" && memo > 0
    @test base.required_bytes + memo < 64*1024^2
    # The metadata-only reader has no Events read method or raw payload.
    small = W.metadata_reader(n,branches;budget=Int(base.required_bytes))
    err = try W.reserve_windowed_selection(small,sel,nothing); nothing catch e; e end
    @test err isa ErrorException
    @test occursin("required_bytes=$(base.required_bytes+memo)",sprint(showerror,err))
    @test W.reserve_windowed_selection(r,sel,nothing) == (base.required_bytes+memo, "")
end
