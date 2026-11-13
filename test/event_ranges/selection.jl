# Standalone: stdlib only, no Cascade load, ROOT input or package precompile.
using Test
module EventRangeSelectionHarness
using Test
const ROOT = normpath(joinpath(@__DIR__, "../.."))
src(parts...) = joinpath(ROOT, "src", parts...)
struct AnalysisConfig
    raw::Dict{String,Any}
    variations::Vector{Any}
end
AnalysisConfig(raw) = AnalysisConfig(Dict{String,Any}(raw), Any[])
for file in ("TriggerConfig", "DataQualityConfig", "column_readers", "decode_options",
             "windowed_selection", "memory_handoff", "streaming_selection_options", "memoization_options", "event_ranges")
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
# Share the real column type with the selection accounting methods.
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
function scalar_selection(; stages=true, nocuts=false)
    cuts=nocuts ? () : ((c,i)->c.cols.x[i]>0, (c,i)->c.cols.y[i]>0)
    CompiledSelection(:mc,nocuts ? String[] : ["x","y"],cuts,0,(c,i,l,h)->nothing,
        (c,i)->c.cols.w[i],(c,i,s)->(c.cols.z[i],1.0),["z","r:early"],
        Dict{String,Vector{String}}(),String[],String[],["w","x"],["y","z"],String[],
        Dict("early"=>(nocuts ? 0 : 1)),nocuts ? 0 : 1,TriggerConfig(),DataQualityConfig(),
        stages ? Dict("y"=>2,"z"=>typemax(Int)) : Dict{String,Int}())
end
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
include(src("Pipeline","run_event_range_pool.jl"))
include(src("Pipeline","event_range_selection.jl"))

function ledger_compare(sel,raw,ranges;workers=1)
    n=length(raw["w"])
    reference,cf=select_events(sel,raw,n;sample="fixture")
    pending=Vector{Any}(undef,length(ranges))
    # This seam uses real incremental IO assembly/progress/select_events. The
    # separate pool suite exercises scheduling/supervision with injected jobs.
    next=Threads.Atomic{Int}(1)
    @sync for _ in 1:workers
        Threads.@spawn begin
            while true
                k=Threads.atomic_add!(next,1)
                k>length(ranges) && break
                r=reader(sel,raw,[ranges[k]])
                haskey(raw,"nK") && (r.counters["K_pt"]="nK")
                payload=read_incremental_selection_window(r,sel,1;stream="",lumimask=nothing)
                stages=Vector{Int}(undef,length(ranges[k]))
                weights=Vector{Float64}(undef,length(ranges[k]))
                table,localcf=select_events(sel,payload.raw,length(ranges[k]);sample="fixture",
                    progress=payload.progress,all_event_stage=stages,all_event_weight=weights,record_cutflow=false)
                @test all(iszero,localcf.n)
                @test all(iszero,localcf.sumw)
                pending[k]=EventRangeResult(table,ranges[k],stages,weights,Dict{String,Any}())
            end
        end
    end
    analysis=StreamSelectionAnalysis(sel,"fixture")
    data=(analysis=analysis,windows=ranges,diagnostics=Dict{String,Any}())
    for k in eachindex(ranges)
        merge_event_range!(data,pending[k],k)
    end
    got=finish_stream_selection!(analysis,n;validate=true)
    @test isequal(got.meta,reference.meta)
    @test got.order==reference.order
    @test all(reinterpret(UInt8,got[name])==reinterpret(UInt8,reference[name]) for name in got.order)
    @test analysis.cutflow.n==cf.n
    @test reinterpret(UInt64,analysis.cutflow.sumw)==reinterpret(UInt64,cf.sumw)
    @test reinterpret(UInt64,analysis.cutflow.sumw2)==reinterpret(UInt64,cf.sumw2)
    return got
end
@testset "authoritative small-range memo bound avoids full-cap reservation" begin
    # The same metadata-only API used by open_event_range_file; no event values
    # or native ROOT access are needed to establish the cache-owned bound.
    metadata=(variable_nodes=((name="derived",),),memoize_max_bytes=268435456)
    small=Selection.variable_memo_reservation(metadata,1)
    larger=Selection.variable_memo_reservation(metadata,100)
    @test small isa Int128
    @test 0 < small <= larger < metadata.memoize_max_bytes
    @test Selection.variable_memo_reservation((variable_nodes=(),memoize_max_bytes=268435456),100)==0
end

@testset "real select_events all-event ledger, progress and canonical jagged" begin
    raw=Dict{String,Any}("w"=>[1e16,1.,-1e16,3.,-2.],"x"=>[1.,1.,1.,-1.,1.],
        "y"=>[-1.,1.,1.,1.,-1.],"z"=>[11.,12.,13.,14.,15.])
    for workers in unique([1,min(2,Threads.nthreads())])
        for sel in (scalar_selection(),scalar_selection(stages=false),scalar_selection(nocuts=true))
            ledger_compare(sel,raw,[1:1,2:3,4:5];workers)
            ledger_compare(sel,raw,[1:5];workers)
            ledger_compare(sel,Dict{String,Any}(k=>v[1:0] for (k,v) in raw),[1:0];workers)
        end
        jagged=Dict{String,Any}("w"=>[1e16,1.,-1e16,3.,-2.],"x"=>[1.,1.,-1.,1.,1.],
            "nJ"=>[1,0,1,1,1],"nK"=>[1,1,1,1,0],
            "J_pt"=>Jagged([[11.],Float64[],[33.],[44.],[55.]]),
            "J_eta"=>Jagged([[-1.],Float64[],[1.],[1.],[1.]]),
            "K_pt"=>Jagged([[101.],[102.],[103.],[104.],Float64[]]))
        # No shared mutable cut counters in the concurrent compiled closures.
        sel=object_selection(zeros(Int,3))
        # Use the same object kernels but replace instrumentation with pure cuts.
        cuts=((c,i)->c.cols.x[i]>0,(c,i)->length(c.objs.j)>=1,
            (c,i)->c.cols.J_eta[first(c.objs.j)]>0)
        args=Tuple(getfield(sel,name) for name in fieldnames(typeof(sel)))
        values=Base.setindex(args,cuts,3)
        pure=CompiledSelection(values...)
        got=ledger_compare(pure,jagged,[1:2,3:5];workers)
        @test got["entry"]==[1,2,4,5]
        @test got["j"]==[11.,0.,44.,55.]
        @test got["k"]==[101.,102.,104.,0.]
    end
end
end # module
