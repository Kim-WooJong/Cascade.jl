"""File-local progress for the ordinary serial reader; never reused for shapes.

Every alive event has passed exactly cuts 1:at. Failed events are terminal;
passed still records their exact cutflow stage. needed is refined in place and
keeps an early-region event even if a later cut fails. Object spans and source
columns have stable flat indexing throughout this invocation.
"""
mutable struct SelectionProgress{S,O,V}
    selection::S
    raw::Dict{String,Any}
    passed::Vector{Int}
    failed::BitVector
    active::Vector{Int}
    needed::Vector{Bool}
    current::Base.RefValue{Int}
    objs::O
    offsets::Dict{String,Vector{Int}}
    at::Int
    memo::V
end

function SelectionProgress(sel::CompiledSelection, raw::Dict{String,Any}, n::Int)
    n >= 0 || throw(ArgumentError("negative event count"))
    current = Ref(0)
    objs = NamedTuple{Tuple(Symbol.(sel.object_names))}(
        Tuple(CachedObjectBuffer(n, current) for _ in sel.object_names))
    return SelectionProgress(sel, raw, zeros(Int, n), falses(n), collect(1:n),
                             fill(true, n), current, objs,
                             Dict{String,Vector{Int}}(), 0,
                             isempty(sel.variable_nodes) ? nothing : VariableMemoRegistry(n, length(sel.variable_nodes), sel.memoize_max_bytes))
end

@inline _progress_built(sel, attempted) =
    sel.mat_at > 0 && attempted >= sel.mat_at ? attempted : 0

function _progress_context(raw, sel, collections, progress::SelectionProgress)
    progress.selection === sel || error("selection progress belongs to another selection")
    progress.raw === raw || error("selection progress belongs to another column store")
    ctx = selection_context(raw, sel, collections; objs = progress.objs, memo = progress.memo)
    for name in keys(ctx.offs)
        offsets = getproperty(ctx.offs, name)
        key = String(name)
        if haskey(progress.offsets, key)
            original = progress.offsets[key]
            (original === offsets || original == offsets) ||
                error("collection offsets changed during incremental selection: $key")
        else
            progress.offsets[key] = offsets
        end
    end
    return ctx
end


include("WindowAccounting.jl")

"""One serial file task's fixed-capacity progress/object pool; no raw/output pool."""

mutable struct WindowBufferReuse{P}
    progress::P
    event_capacity::Int
    reserved_bytes::Int
    creations::Int
    resets::Int
    accounting::Union{Nothing,WindowAccounting}
end
function WindowBufferReuse(sel::CompiledSelection, n::Int, object_bounds)
    isempty(sel.variable_nodes) || throw(ArgumentError("reuse_window_buffers does not support variable memo"))
    length(object_bounds) == length(sel.object_names) || error("object bound mapping mismatch")
    p = SelectionProgress(sel, Dict{String,Any}(), n)
    objs = NamedTuple{keys(p.objs)}(Tuple(begin
        data = Vector{Int}(undef, bound)
        empty!(data)
        CachedObjectBuffer(data, buf.spans, p.current, bound)
    end for (buf, bound) in zip(p.objs, object_bounds)))
    p = SelectionProgress(sel, p.raw, p.passed, p.failed, p.active, p.needed,
        p.current, objs, p.offsets, 0, nothing)
    # Full capacity, never logical length; 2x payload allowance plus fixed headers.
    payload = Base.checked_add(Base.checked_mul(n, 17 + 16length(object_bounds)), cld(n, 8))
    payload = Base.checked_add(payload, Base.checked_mul(8, sum(object_bounds; init=0)))
    reserved = Base.checked_add(Base.checked_mul(2, payload), 4096(2length(object_bounds) + 4))
    return WindowBufferReuse(p, n, reserved, 1, 0, nothing)
end
function detach_window_buffers!(pool::WindowBufferReuse)
    pool.progress.raw = Dict{String,Any}()
    empty!(pool.progress.offsets) # never mutate borrowed offsets
    return nothing
end
function reset_window_buffers!(pool::WindowBufferReuse, sel, raw::Dict{String,Any}, n::Int)
    p = pool.progress
    p.selection === sel || error("selection progress belongs to another selection")
    0 <= n <= pool.event_capacity || error("reusable event metadata bound exceeded")
    p.raw = raw
    resize!(p.passed, n); fill!(p.passed, 0)
    resize!(p.failed, n); fill!(p.failed, false)
    resize!(p.active, n)
    for i in 1:n; p.active[i] = i; end
    resize!(p.needed, n); fill!(p.needed, true)
    p.current[] = 0; p.at = 0
    empty!(p.offsets)
    for buf in p.objs
        empty!(buf.data)
        resize!(buf.spans, n); fill!(buf.spans, 0:-1)
    end
    pool.resets += 1
    return p
end
