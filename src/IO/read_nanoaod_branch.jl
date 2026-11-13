# Internal proof that canonical metadata was checked once. The vector remains
# shared read-only metadata; callers must not mutate returned Jagged offsets.
struct _ValidatedNanoAODOffsets
    values::Vector{Int}
    function _ValidatedNanoAODOffsets(values::Vector{Int})
        (!isempty(values) && first(values) == 0 && issorted(values)) ||
            throw(ArgumentError("invalid canonical offsets"))
        return new(values)
    end
end

function _nanoaod_offsets(offsets::Vector{Int}, n, name)
    length(offsets) == n + 1 || throw(ArgumentError("offsets length mismatch for $name"))
    (first(offsets) == 0 && issorted(offsets)) ||
        throw(ArgumentError("invalid canonical offsets for $name"))
    return offsets
end

function _nanoaod_offsets(offsets::_ValidatedNanoAODOffsets, n, name)
    length(offsets.values) == n + 1 || throw(ArgumentError("offsets length mismatch for $name"))
    return offsets.values
end

"""
    read_nanoaod_branch(file, tree, name; needed = nothing, offsets = nothing) -> Vector or Jagged

Read one TTree branch by iterating its baskets.

If `needed` is given, baskets containing no event with `needed[i] == true` are
not decompressed and their events get zero values. For jagged branches this
requires `offsets` (canonical per-event offsets, e.g. from the `nX` counter
branch) so that every branch of a collection stays aligned; without `offsets`
a jagged branch is read completely.
"""
function read_nanoaod_branch(file, tree::AbstractString, name::AbstractString;
                             needed::Union{Nothing,AbstractVector{Bool}} = nothing,
                             offsets::Union{Nothing,Vector{Int},_ValidatedNanoAODOffsets} = nothing,
                             scratch::Union{Nothing,_NanoAODScratch} = nothing)
    lb = UnROOT.LazyBranch(file, string(tree, "/", name))
    n = length(lb)
    nb = UnROOT.numbaskets(lb.b)
    starts = lb.fEntry
    # Masked undef storage is safe only when basket ranges cover 1:n in order.
    (length(starts) == nb + 1 && !isempty(starts) && first(starts) == 0 &&
     last(starts) == n && issorted(starts)) || (starts = nothing; needed = nothing)
    needed === nothing || length(needed) == n ||
        throw(ArgumentError("needed mask length $(length(needed)) != $n events"))
    T = eltype(lb)
    if T <: AbstractVector
        if needed === nothing || offsets === nothing
            return _read_jagged_all(lb, n, nb, eltype(T))
        end
        canonical = _nanoaod_offsets(offsets, n, name)
        state = _reusable_branch(lb, scratch, starts, eltype(T), true)
        try
            return _read_jagged_masked(lb, nb, starts, needed, canonical, eltype(T), name; state)
        finally
            _close_reusable_branch(state)
        end
    end
    state = _reusable_branch(lb, scratch, starts, T, false)
    try
        return _read_flat(lb, n, nb, starts, needed, T; state)
    finally
        _close_reusable_branch(state)
    end
end

_skip(needed, starts, ib) = needed !== nothing && !any(view(needed, starts[ib]+1:starts[ib+1]))

function _read_flat(lb, n, nb, starts, needed, ::Type{T}; state = nothing) where {T}
    data = Vector{T}(undef, n)
    pos = 0
    for ib in 1:nb
        if _skip(needed, starts, ib)
            m = starts[ib+1] - starts[ib]
            fill!(view(data, pos+1:pos+m), zero(T))
            pos += m
            continue
        end
        if state !== nothing
            m = starts[ib+1] - starts[ib]
            if _read_reusable_basket!(data, pos, lb, ib, state, m)
                pos += m
                continue
            end
        end
        ba = UnROOT.basketarray(lb, ib)
        m = length(ba)
        copyto!(data, pos + 1, ba, 1, m)
        pos += m
    end
    pos == n || error("branch read $pos of $n entries")
    return data
end

_flat_basket(ba) = hasproperty(ba, :elem_ptr) && hasproperty(ba, :data) &&
                   first(ba.elem_ptr) == 1 && last(ba.elem_ptr) - 1 == length(ba.data)

function _read_jagged_all(lb, n, nb, ::Type{E}) where {E}
    content = E[]
    offsets = Vector{Int}(undef, n + 1)
    offsets[1] = 0
    pos = 0
    for ib in 1:nb
        ba = UnROOT.basketarray(lb, ib)
        if _flat_basket(ba)
            ep = ba.elem_ptr
            base = offsets[pos+1]
            append!(content, ba.data)
            for k in 1:length(ba)
                offsets[pos+k+1] = base + Int(ep[k+1]) - 1
            end
        else
            for (k, v) in enumerate(ba)
                append!(content, v)
                offsets[pos+k+1] = offsets[pos+k] + length(v)
            end
        end
        pos += length(ba)
    end
    pos == n || error("branch read $pos of $n entries")
    return Jagged{E}(content, offsets)
end

function _read_jagged_masked(lb, nb, starts, needed, offsets::Vector{Int}, ::Type{E}, name; state = nothing) where {E}
    content = Vector{E}(undef, offsets[end])
    for ib in 1:nb
        lo = starts[ib] + 1
        hi = starts[ib+1]
        if _skip(needed, starts, ib)
            # Keep historical basket-level zero semantics, including empty ranges.
            fill!(view(content, offsets[lo]+1:offsets[hi+1]), zero(E))
            continue
        end
        if _read_reusable_basket!(content, offsets[lo], lb, ib, state, hi-lo+1; canonical = offsets, lo)
            continue
        end
        ba = UnROOT.basketarray(lb, ib)
        length(ba) == hi - lo + 1 || error("$name: basket $ib has $(length(ba)) entries, expected $(hi - lo + 1)")
        dst = offsets[lo]
        m = offsets[hi+1] - dst
        if _flat_basket(ba)
            length(ba.data) == m || error("$name: basket $ib content does not match counter branch")
            copyto!(content, dst + 1, ba.data, 1, m)
        else
            for (k, v) in enumerate(ba)
                e = lo + k - 1
                length(v) == offsets[e+1] - offsets[e] || error("$name: event $e length mismatch with counter")
                copyto!(content, offsets[e] + 1, v, 1, length(v))
            end
        end
    end
    # Canonical offsets are read-only input metadata shared by sibling columns.
    return Jagged{E}(content, offsets)
end
