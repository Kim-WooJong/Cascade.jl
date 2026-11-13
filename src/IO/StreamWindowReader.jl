"""Exclusive reader state. Never passed to an analysis job."""
struct StreamWindowReader
    source::NanoAODSource
    branches::Dict{String,Any}
    pre::Vector{String}
    post::Vector{String}
    counters::Dict{String,String}
    windows::Vector{UnitRange{Int}}
    charges::Vector{Int}
    options::Any
    diagnostics::Dict{String,Any}
    seen::Set{Tuple{String,Int}}
end

"""Concrete isbits per-basket plan descriptor (1-based inclusive event span)."""
const StreamBasketDesc = NamedTuple{(:lo,:hi,:bytes,:decoded,:keylen),NTuple{5,Int}}

"""
    stream_basket_overlap(baskets, range) -> UnitRange{Int}

Original indices of every basket with `lo<=last(range) && hi>=first(range)`,
found by binary search in O(log nb). CONTRACT (not re-checked per query): both
`.lo` and `.hi` are nondecreasing over `baskets`. `plan_stream_windows` (the
metadata owner) enforces this once: starts are validated sorted and unique, so
lo/hi are strictly increasing. Under that contract the overlap set is exactly
the intersection of an upward-closed set (hi>=first) and a downward-closed set
(lo<=last), i.e. a contiguous index interval; the result equals a full linear
scan, including straddling baskets (callers still raise their split errors) and
empty ranges. Seam callers building descriptors by hand must honour it.
"""
function stream_basket_overlap(baskets::AbstractVector,range::AbstractUnitRange)
    f=first(range);l=last(range);nb=length(baskets)
    lo=1;hi=nb+1                    # first i with baskets[i].hi>=f
    while lo<hi
        m=(lo+hi)>>>1
        baskets[m].hi>=f ? (hi=m) : (lo=m+1)
    end
    i=lo
    lo=0;hi=nb                      # last j with baskets[j].lo<=l
    while lo<hi
        m=(lo+hi+1)>>>1
        baskets[m].lo<=l ? (lo=m) : (hi=m-1)
    end
    return i:max(lo,i-1)
end

"""Metadata-only common-boundary plan. No Events basket is decompressed here.

Common boundaries ensure a basket cannot straddle adjacent admitted windows.
Unsupported layout returns a reason; malformed metadata and budget excess throw.
`counter_names` (default: `post`, the unchanged legacy mapping) selects names
whose `n<collection>` counter is planned; the opt-in reusable decoder passes
pre and post so jagged pre columns also get canonical counter offsets.
`indexed_branch_lookup` (default false: unchanged public per-name lookup) is passed
true only by the opt-in reusable decoder; it resolves the same TBranch objects and
ROOTFile.cache entries through one plan-local scan (stream_plan_branch_lookup.jl),
and any shape that scan does not support (including any UnROOT other than exactly 0.11.11;
support methods live in IO.jl) falls back to the public lookup. The temporary index is
made unreachable after the branch loop, before metadata sizing.
"""
function plan_stream_windows(src::NanoAODSource, pre, post, output_columns, options; counter_names = post,
        indexed_branch_lookup = false)
    column_read_eligibility(src) == "" || return nothing, column_read_eligibility(src)
    n = nevents(src); available = Set(column_names(src))
    counters = Dict{String,String}()
    for name in counter_names
        c = "n" * first(split(name,'_'))
        c in available && (counters[name] = c)
    end
    names = unique(vcat(pre,collect(values(counters)),post))
    branches = Dict{String,Any}(); common = nothing
    lookup = indexed_branch_lookup === true ? stream_plan_branch_index(src.file, src.tree, names) : nothing
    for name in names
        b = lookup === nothing ? src.file[string(src.tree,"/",name)] : stream_plan_branch(src.file, src.tree, name, lookup)
        ismissing(b) && error("missing stream branch: $name")
        b isa UnROOT.TBranch || return nothing,"unsupported_branch"
        length(b.fLeaves.elements) == 1 || return nothing,"unsupported_multi_leaf"
        T,J = UnROOT.auto_T_JaggT(src.file,b;customstructs=src.file.customstructs)
        E = T <: AbstractVector ? eltype(T) : T
        haskey(COLFILE_TYPES,string(E)) || return nothing,"unsupported_primitive"
        decode_interpretation_supported(b,T,J) || return nothing,"unsupported_interpretation"
        index,reason=stream_basket_index(b)
        isempty(reason) || return nothing,reason
        nb=index.count;starts=index.starts
        length(b) == n && starts[1] == 0 && starts[end] == n && issorted(starts) || error("malformed stream basket index: $name")
        length(unique(starts)) == length(starts) || return nothing,"empty_baskets"
        common = common === nothing ? Set(starts) : intersect!(common,Set(starts))
        bs = Vector{StreamBasketDesc}(undef,0); sizehint!(bs,nb)
        for ib in 1:nb
            pos=Int(b.fBasketSeek[ib]); bytes=Int(b.fBasketBytes[ib])
            pos == 0 && return nothing,"recovered_basket"
            bytes >= 16 && pos >= 0 && Int128(pos)+bytes <= length(src.file.fobj.mmap_ary) || error("stream basket outside source")
            h=IOBuffer(UnROOT.read_seek_nb(src.file.fobj,pos,16))
            declared=Int(UnROOT.readtype(h,Int32));version=UnROOT.readtype(h,Int16)
            decoded=Int(UnROOT.readtype(h,Int32));UnROOT.readtype(h,UInt32);keylen=Int(UnROOT.readtype(h,Int16))
            declared==bytes && version>0 && 16<=keylen<=min(bytes,65536) && decoded>=0 || error("invalid stream basket header")
            max(bytes,decoded)<=options.stream_basket_bytes || error("stream basket exceeds stream_basket_bytes")
            push!(bs,StreamBasketDesc((starts[ib]+1,starts[ib+1],bytes,decoded,keylen)))
        end
        branches[name]=(lazy=UnROOT.LazyBranch(src.file,string(src.tree,"/",name)),T=T,E=E,jagged=T<:AbstractVector,maskable=index.maskable,baskets=bs)
    end
    lookup = nothing   # drop temporary plan-local lookup scratch (unreachable) before metadata sizing
    cuts = common === nothing ? [0,n] : sort!(collect(common))
    windows=stream_window_ranges(cuts,n,options.stream_window_events)
    n>options.stream_window_events && length(windows)<=1 && return nothing,"no_bounded_common_boundary"
    charges=Int[]
    for range in windows
        decoded=Int128(0);scratch=Int128(0)
        for br in values(branches),ib in stream_basket_overlap(br.baskets,range)
            bs=br.baskets[ib]
            first(range)<=bs.lo<=bs.hi<=last(range) || error("stream plan splits basket")
            decoded+=bs.decoded;scratch=max(scratch,3Int128(bs.decoded)+3Int128(bs.bytes))
        end
        # All branches, canonical offsets, masks, contexts, growth/copy slack,
        # selected-window output, plus one transient native/basket workspace.
        raw=decoded+16Int128(length(range))*length(branches)+4Int128(length(range))
        raw<=options.stream_window_bytes || error("stream window exceeds stream_window_bytes")
        charge=16raw+scratch+16Int128(length(range))*(output_columns+3)+4096*(length(branches)+1)
        charge<=options.stream_queue_bytes-options.stream_metadata_bytes || error("stream window reservation exceeds stream_queue_bytes")
        push!(charges,Int(charge))
    end
    # LazyBranch borrows ROOTFile/mmap: recursively sizing it would charge the
    # entire mapped input as metadata. Size owned descriptors and parsed tree,
    # with per-thread empty lazy-buffer/lock allowance, never mmap length.
    descriptor_bytes=Base.summarysize([(name=name,baskets=br.baskets) for (name,br) in branches])
    metadata_bytes=descriptor_bytes+Base.summarysize(src.file[src.tree])+Base.summarysize(windows)+Base.summarysize(charges)+1024Threads.nthreads()*length(branches)
    metadata_bytes<=options.stream_metadata_bytes || error("stream plan exceeds stream_metadata_bytes")
    unmaskable=sort!([name for (name,br) in branches if !br.maskable])
    padded_counts=Dict(name=>length(branches[name].baskets) for name in unmaskable)
    diag=Dict{String,Any}("mode"=>isempty(unmaskable) ? "common_boundary_exact_indices" : "common_boundary_per_branch_maskability",
        "unmaskable_branches"=>unmaskable,"unmaskable_branch_count"=>length(unmaskable),
        "padded_branch_basket_counts"=>padded_counts,"padded_decoded_baskets"=>0,
        "padded_decoded_compressed_bytes"=>0,"padded_decoded_declared_bytes"=>0,
        "raw_indices_unchanged"=>true,"windows_planned"=>length(windows),"max_window_events"=>maximum(length,windows;init=0),
        "common_boundary_count"=>length(cuts),"prefix_events"=>0,"prefix_pass"=>0,"unique_baskets"=>0,"repeated_baskets"=>0,
        "max_raw_window_bytes"=>0)
    return StreamWindowReader(src,branches,String.(pre),String.(post),counters,windows,charges,options,diag,Set{Tuple{String,Int}}()),""
end

function read_stream_branch(r::StreamWindowReader,name,range;needed=nothing,offsets=nothing,phase="pre",
        basket_observer=(_)->nothing)
    return read_stream_branch_owned(r.branches[name],name,range,r.options,r.diagnostics,r.seen;
        needed,offsets,phase,basket_observer)
end

# Source-free assembly seam also supports deterministic ownership/corruption tests.
stream_basket_array(br,ib)=UnROOT.basketarray(br.lazy,ib)
function read_stream_branch_owned(br,name,range,options,diagnostics,seen;
        needed=nothing,offsets=nothing,phase="pre",basket_reader=stream_basket_array,
        basket_observer=(_)->nothing)
    # Match ORIGINAL read_nanoaod_branch: invalid exact raw index shape disables
    # needed first. For validated zero-tail padding, ignore counter offsets too.
    # Only THIS branch changes; exact-index siblings keep their mask and guards.
    if !br.maskable
        needed=nothing;offsets=nothing
    end
    n=length(range);needed===nothing || length(needed)==n || error("stream mask length mismatch")
    offsets===nothing || (length(offsets)==n+1 && first(offsets)==0 && issorted(offsets)) || error("invalid canonical stream offsets")
    E=br.E
    masked=br.jagged && needed!==nothing && offsets!==nothing
    masked && Int128(last(offsets))*sizeof(E)+8Int128(n+1)>options.stream_window_bytes && error("stream canonical offsets exceed window budget")
    if masked
        declared=sum((Int128(br.baskets[ib].decoded) for ib in stream_basket_overlap(br.baskets,range));init=Int128(0))
        Int128(last(offsets))*sizeof(E)<=declared || error("stream canonical offsets exceed declared basket payload")
    end
    data=br.jagged ? (masked ? zeros(E,last(offsets)) : E[]) : Vector{E}(undef,n)
    outoffsets=br.jagged ? (masked ? copy(offsets) : zeros(Int,n+1)) : Int[]
    for ib in stream_basket_overlap(br.baskets,range)
        bs=br.baskets[ib]
        first(range)<=bs.lo<=bs.hi<=last(range) || error("stream read splits basket")
        lo=bs.lo-first(range)+1;hi=bs.hi-first(range)+1
        skip=(!br.jagged || masked) && needed!==nothing && !any(view(needed,lo:hi))
        action=skip ? "skipped" : "decoded";d=diagnostics
        for (suffix,value) in (("baskets",1),("compressed_bytes",bs.bytes),("compressed_payload_bytes",bs.bytes-bs.keylen),("declared_decoded_bytes",bs.decoded))
            key=string(phase,"_",action,"_",suffix);d[key]=get(d,key,0)+value
        end
        basket_observer((phase=phase,name=name,basket=ib,decoded=!skip,
            compressed_bytes=bs.bytes,compressed_payload_bytes=bs.bytes-bs.keylen,declared_decoded_bytes=bs.decoded))
        if !br.maskable && !skip
            d["padded_decoded_baskets"]=get(d,"padded_decoded_baskets",0)+1
            d["padded_decoded_compressed_bytes"]=get(d,"padded_decoded_compressed_bytes",0)+bs.bytes
            d["padded_decoded_declared_bytes"]=get(d,"padded_decoded_declared_bytes",0)+bs.decoded
        end
        if skip
            br.jagged || fill!(view(data,lo:hi),zero(E));continue
        end
        token=(name,ib)
        d[token in seen ? "repeated_baskets" : "unique_baskets"]+=1;push!(seen,token)
        basket=basket_reader(br,ib)
        length(basket)==hi-lo+1 || error("stream decoded basket entry mismatch")
        if br.jagged
            if masked
                for (k,v) in enumerate(basket)
                    row=lo+k-1;length(v)==offsets[row+1]-offsets[row] || error("stream jagged/counter mismatch")
                    copyto!(data,offsets[row]+1,v,1,length(v))
                end
            else
                for (k,v) in enumerate(basket)
                    row=lo+k-1;Int128(length(data)+length(v))*sizeof(E)+8Int128(n+1)<=options.stream_window_bytes || error("stream jagged output exceeds window budget");append!(data,v);outoffsets[row+1]=length(data)
                end
            end
        else
            copyto!(data,lo,basket,1,hi-lo+1)
        end
    end
    return br.jagged ? Jagged(data,outoffsets) : data
end

"""Validate physical range geometry without changing the original mask contract.

Exact raw indices are maskable. A longer array is supported ONLY with a valid
strict 0..n prefix and entirely zero tail; its copied prefix plans common cuts,
while maskable=false preserves ORIGINAL full basket reads/actual jagged offsets.
The raw branch and LazyBranch.fEntry arrays are never mutated.
"""
function stream_basket_index(branch;basket_count=UnROOT.numbaskets)
    count=try
        basket_count(branch)
    catch e
        e isa MethodError || rethrow()
        return nothing,"unsupported_basket_index"
    end
    count isa Integer && !(count isa Bool) && 0<=count<typemax(Int) || return nothing,"unsupported_basket_index"
    raw=branch.fBasketEntry
    length(raw)>=count+1 || return nothing,"unsupported_basket_index"
    starts=Int.(raw[1:count+1]);n=Int(branch.fEntries)
    n>=0 && starts[1]==0 && starts[end]==n && issorted(starts) || error("malformed stream basket index")
    length(unique(starts))==length(starts) || return nothing,"empty_baskets"
    maskable=length(raw)==count+1
    maskable || all(iszero,view(raw,count+2:length(raw))) || return nothing,"unsupported_basket_index"
    return (count=Int(count),starts=starts,maskable=maskable),""
end

"""Preserve established groups; repair a target-overshoot single-window edge.

If n is just past the target, a final cut used to swallow the valid interior
common cuts. Split at an EXISTING common cut, never inside a basket. A source
with no interior common boundary still reaches the existing refusal unchanged.
"""
function stream_window_ranges(cuts,n,target)
    windows=UnitRange{Int}[];beginat=0
    for cut in cuts[2:end]
        if cut-beginat>=target || cut==n
            push!(windows,beginat+1:cut);beginat=cut
        end
    end
    n==0 && push!(windows,1:0)
    if n>target && length(windows)==1 && length(cuts)>2
        k=clamp(searchsortedlast(cuts,target),2,length(cuts)-1)
        split=cuts[k]
        windows=[1:split,split+1:n]
    end
    return windows
end
