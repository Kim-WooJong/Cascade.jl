"""Stable, definition-scoped identity (lexicographic variable-name order)."""
struct NodeID{N} end

struct VariableNode{I,F}
    id::I
    name::String
    compute::F
    usage::ExpressionUsage
end

const VARIABLE_MEMO_TYPES = (Bool, Int8, Int16, Int32, Int64, Int128,
    UInt8, UInt16, UInt32, UInt64, UInt128, Float16, Float32, Float64,
    Complex{Float16}, Complex{Float32}, Complex{Float64})
const VARIABLE_MEMO_MAX_VALUE_BYTES = maximum(sizeof, VARIABLE_MEMO_TYPES)
const VariableMemoDiagnostic = NamedTuple{(:node, :name, :reason),Tuple{Int,String,String}}
const VARIABLE_MEMO_REASON_BYTES = 128
const VARIABLE_MEMO_TYPE_REASON = "unsupported inferred type; require concrete built-in fixed-size numeric scalar"
const VARIABLE_MEMO_BUDGET_REASON = "memoize_max_bytes exhausted"

# Fixed-capacity storage exposes only initialized diagnostics but keeps the full
# backing vector visible to Base.summarysize/incremental_window_bytes.
mutable struct VariableMemoDiagnostics
    storage::Vector{VariableMemoDiagnostic}
    count::Int
end
VariableMemoDiagnostics(n::Int) = VariableMemoDiagnostics(
    fill((node=0, name="", reason=""), n), 0)
Base.length(d::VariableMemoDiagnostics) = d.count
Base.isempty(d::VariableMemoDiagnostics) = iszero(d.count)
Base.eltype(::Type{VariableMemoDiagnostics}) = VariableMemoDiagnostic
Base.IteratorSize(::Type{VariableMemoDiagnostics}) = Base.HasLength()
Base.iterate(d::VariableMemoDiagnostics, i::Int=1) = i > d.count ? nothing : (d.storage[i], i+1)
Base.copy(d::VariableMemoDiagnostics) = d.storage[1:d.count]
function Base.getindex(d::VariableMemoDiagnostics, i::Int)
    1 <= i <= d.count || throw(BoundsError(d,i))
    return d.storage[i]
end
function Base.push!(d::VariableMemoDiagnostics, value::VariableMemoDiagnostic)
    d.count < length(d.storage) || error("memo diagnostic capacity exceeded")
    d.storage[d.count + 1] = value
    d.count += 1
    return d
end

"""Cold, workunit-owned registry. Only concrete slots reach compiled getters."""
mutable struct VariableMemoRegistry
    n::Int
    max_bytes::Int
    allocated_bytes::Int
    slots::Vector{Any}
    diagnostics::VariableMemoDiagnostics
end
function VariableMemoRegistry(n::Int, count::Int, max_bytes::Int=268435456)
    n >= 0 && count >= 0 && max_bytes > 0 || throw(ArgumentError("invalid variable memo dimensions/budget"))
    # Reserve once; at most one diagnostic per node, so no geometric growth.
    diagnostics = VariableMemoDiagnostics(count)
    return VariableMemoRegistry(n, max_bytes, 0, Any[nothing for _ in 1:count], diagnostics)
end

struct VariableMemoColumn{T}
    values::Vector{T}
    valid::Vector{Bool}  # byte validity: no packed-word ownership surprises
end
struct UncachedVariable end

const VARIABLE_MEMO_COLUMN_OVERHEAD = Base.summarysize(VariableMemoColumn(UInt128[], Bool[]))
const VARIABLE_MEMO_REGISTRY_OVERHEAD = Base.summarysize(VariableMemoRegistry(0, 0, 1))
# Full diagnostic capacity (not only length), slot references, strings, and
# alignment slack. Names are charged below even though shared with the plan.
const VARIABLE_MEMO_NODE_METADATA = sizeof(Ptr{Cvoid}) + sizeof(VariableMemoDiagnostic) +
    2Base.summarysize("") + VARIABLE_MEMO_REASON_BYTES + 128

"""
    variable_memo_reservation(sel, n::Int)::Int128

Metadata-only upper bound for the complete workunit registry plus admitted
column capacities. Does not reserve the full configured cap for small ranges.
No event values/types are inspected; admission and this bound share the same
native dtype whitelist. Excludes shared kernels/compiler scratch and raw input.
"""
function variable_memo_reservation(sel, n::Int)::Int128
    n >= 0 || throw(ArgumentError("negative event count"))
    count = length(sel.variable_nodes)
    count == 0 && return Int128(0)
    cap = Int128(sel.memoize_max_bytes)
    per_node = Int128(VARIABLE_MEMO_COLUMN_OVERHEAD) +
        Int128(n) * (VARIABLE_MEMO_MAX_VALUE_BYTES + sizeof(Bool))
    # Clip before multiplying so even typemax(Int) dimensions cannot overflow.
    columns = min(cap, Int128(count) * min(cap, per_node))
    metadata = Int128(VARIABLE_MEMO_REGISTRY_OVERHEAD) +
        Int128(count) * VARIABLE_MEMO_NODE_METADATA
    for node in sel.variable_nodes
        metadata += ncodeunits(node.name)
    end
    return columns + metadata
end

@inline function _variable_value(f::F, ctx, i::Int, column::VariableMemoColumn{T}) where {F,T}
    if column.valid[i]
        return column.values[i]
    end
    # Never set validity on exceptions; demand remains at its original guard.
    value = f(ctx, i)::T  # assert only, never convert or round
    column.values[i] = value
    column.valid[i] = true
    return value
end
@inline _variable_value(f::F, ctx, i::Int, ::UncachedVariable) where F = f(ctx, i)
@inline _variable_value(f::F, ctx, i::Int, ::Nothing) where F = f(ctx, i)
@inline _variable_slot(::Nothing, ::NodeID) = nothing
@inline _variable_slot(slots::Tuple, ::NodeID{N}) where N = getfield(slots, N)

# Each node body has nested demand getters but inference sees a memo-free
# context. This avoids recursive type discovery and computes no event values.
function _memo_fallback!(registry, node, reason)
    id = _node_index(node.id)
    any(entry -> entry.node == id, registry.diagnostics) && return UncachedVariable()
    # Never render an arbitrary inferred type: it may have unbounded display.
    ncodeunits(reason) <= VARIABLE_MEMO_REASON_BYTES || error("unbounded memo diagnostic")
    length(registry.diagnostics) < length(registry.slots) || error("duplicate memo diagnostic capacity")
    entry = (node=id, name=node.name, reason=String(reason))
    push!(registry.diagnostics, entry)
    @warn "Variable memo uses uncached demand evaluation" node=entry.node variable=entry.name reason=entry.reason
    return UncachedVariable()
end

function _new_variable_slot(node, ctx, registry)
    T = Base.invokelatest(Core.Compiler.return_type, node.compute, Tuple{typeof(ctx),Int})
    # Bound ownership and size: cache only concrete, isbits scalar Numbers.
    # Union/Any, allocating and reference-containing results stay unchanged.
    if T isa DataType && T in VARIABLE_MEMO_TYPES
        per_event = sizeof(T) + sizeof(Bool)
        # Division avoids overflow before admission; charge array headers too.
        overhead = VARIABLE_MEMO_COLUMN_OVERHEAD
        available = max(0, registry.max_bytes - registry.allocated_bytes - overhead)
        if registry.n <= div(available, per_event) && overhead <= registry.max_bytes - registry.allocated_bytes
            slot = VariableMemoColumn(Vector{T}(undef, registry.n), fill(false, registry.n))
            registry.allocated_bytes += Base.summarysize(slot)
            return slot
        end
        return _memo_fallback!(registry, node,
            VARIABLE_MEMO_BUDGET_REASON)
    end
    return _memo_fallback!(registry, node,
        VARIABLE_MEMO_TYPE_REASON)
end
_node_index(::NodeID{N}) where N = N

function _memo_context(ctx, sel, registry::VariableMemoRegistry)
    # Newly constructed partial contexts can expose additional inputs. Never
    # install a slot until *all transitive* dependencies exist. Mask validity
    # is still governed by the original stage/prefix execution, not by discovery.
    inference_ctx = KernelContext(ctx.cols, ctx.offs, ctx.objs)
    for (k, node) in enumerate(sel.variable_nodes)
        registry.slots[k] === nothing || continue
        u = node.usage
        all(name -> hasproperty(ctx.cols, Symbol(name)), union(u.columns, u.builtins)) || continue
        all(name -> hasproperty(ctx.offs, Symbol(name)), u.collections) || continue
        registry.slots[k] = _new_variable_slot(node, inference_ctx, registry)
    end
    return KernelContext(ctx.cols, ctx.offs, ctx.objs, Tuple(registry.slots))
end

"""Owned cache bytes only, excluding shared compiled kernels and config."""
variable_memo_bytes(::Nothing) = 0
variable_memo_bytes(registry::VariableMemoRegistry) = Base.summarysize(registry)
variable_memo_diagnostics(registry::VariableMemoRegistry) = copy(registry.diagnostics)
