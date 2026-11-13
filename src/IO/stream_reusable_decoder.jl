# Opt-in stage1 A prototype (execution.windowed_reusable_decoder, default false).
#
# Modern reusable basket decoder -> window-owned typed Vector/Jagged -> existing
# typed selection kernels. MODERN-ONLY policy: this file never calls the legacy
# UnROOT basket reader. A demanded basket that the reusable decoder declines
# (returns false before touching its destination) is an explicit
# WindowedReusableUnsupported error; corruption detected after admission
# propagates unchanged. Nothing here catches, retries or reroutes a file.
#
# Ownership: one StreamDecodeState per file, owned by the serial task that owns
# the StreamWindowReader. Its scratch is reused across baskets/branches/windows
# (bounded by _nanoaod_scratch_limit()); native codec state lives only inside one
# branch read and is finalized in 'finally' before the caller closes the source.
# Window destination CONTENT is always freshly allocated and never aliases scratch
# or siblings. Jagged destination OFFSETS are a private copy by default. Only with
# execution.reusable_shared_offsets (config default: follows windowed_reusable_decoder;
# this low-level state's share_window_offsets keyword defaults to false) may sibling jagged
# outputs BORROW the offsets vector that THIS state issued for its CURRENT window
# counter record (proof: _proven_window_offsets). A borrowed offsets vector is a
# mutable Vector{Int} shared with that record and every sibling: callers must
# never mutate or resize it for its whole reachable lifetime (also after return,
# window advance, release or source close); mutate only a private copy.
# Requests with stale/foreign/unissued/substituted vectors, or for a branch that is
# not this state's own planned branch, take the copy route.
# Counters keep only one checked file-cumulative Int per collection: no
# full-file raw payload, counter array or prefix is materialized.

"""Explicit unsupported condition of the opt-in modern-only window decoder.

Never a fallback signal: callers propagate it instead of using another reader.
"""
struct WindowedReusableUnsupported <: Exception
    subject::String
    reason::String
end
Base.showerror(io::Base.IO, e::WindowedReusableUnsupported) =
    print(io, "execution.windowed_reusable_decoder unsupported for ", e.subject, ": ", e.reason,
        " (modern-only path; no legacy decoder fallback or ordinary-reader retry)")

const REUSABLE_STAT_KEYS = ("decoded_baskets", "skipped_baskets", "duplicate_basket_decodes", "padded_decoded_baskets",
    "decoded_declared_bytes", "destination_bytes", "destination_allocated_bytes", "offset_copy_bytes",
    "scratch_capacity_highwater_bytes", "live_highwater_bytes", "owned_window_highwater_bytes",
    "retained_table_highwater_bytes")

"""Serial per-file modern decoder state. Concrete seam types (decoder/branch/close)
let focused tests inject declines/corruption; production uses the real functions."""
mutable struct StreamDecodeState{D,B,C}
    scratch::_NanoAODScratch
    decoder::D
    branch::B
    close::C
    counters::Vector{String}
    counter_base::Dict{String,Int}     # checked file-cumulative total before next window
    counter_next::Dict{String,Int}     # next expected original (1-based) event
    counter_window::Dict{String,Int}   # last window index validated (exactly once/window)
    sibling_reuses::Dict{String,Int}
    decoded_ids::Dict{String,Vector{Int}}
    skipped_ids::Dict{String,Vector{Int}}
    padded_proven::Set{String}         # maskable=false branches proven by reusable_stream_admission
    window::Int
    live_states::Int
    stats::Dict{String,Int}
    share_window_offsets::Bool         # resolved execution.reusable_shared_offsets (keyword default false)
    # Opt-in sharing proof (empty/inert by default). Owner identity is held STRONGLY but only
    # through plain-data arrays the owner plan already owns (seen-set, basket descriptors,
    # integer fEntry): never the reader, LazyBranch, ROOT file, source or mmap graph.
    # Issued offsets are WEAK, so the proof never keeps a window record/payload alive.
    branch_counter::Dict{String,String} # planned jagged branch => counter (private copy of the plan map)
    branch_ids::Dict{String,Tuple{Vector{StreamBasketDesc},Vector{Int}}} # planned branch => (baskets, lazy.fEntry)
    owner_seen::Union{Nothing,Set{Tuple{String,Int}}} # the owning reader's seen-set (identity only)
    record_window::Int                  # window whose complete counter record THIS state issued (0 = none)
    record_range::UnitRange{Int}        # that window's event range
    record_refs::Vector{WeakRef}        # issued offsets vector per d.counters entry
    proof_reserved::Int                 # opt-in proof metadata bytes measured at construction (0 by default);
                                        # reserved before any Events read via reusable_reservation_bytes(r, d)
end

const REUSABLE_SHARED_OFFSET_STAT_KEYS = ("shared_offset_aliases", "avoided_offset_copy_bytes")

function StreamDecodeState(r::StreamWindowReader; scratch = _NanoAODScratch(),
        decoder = _read_reusable_basket!, branch = _reusable_branch, close = _close_reusable_branch,
        share_window_offsets::Bool = false)
    counters = sort!(unique!(String[String(c) for c in values(r.counters)]))
    first_event = isempty(r.windows) ? 1 : first(first(r.windows))
    zero_by_counter() = Dict{String,Int}(c => 0 for c in counters)
    stats = Dict{String,Int}(k => 0 for k in REUSABLE_STAT_KEYS)
    # Extra keys only when requested: the default state/diagnostics are unchanged.
    if share_window_offsets
        for k in REUSABLE_SHARED_OFFSET_STAT_KEYS; stats[k] = 0; end
    end
    share = share_window_offsets
    d = StreamDecodeState(scratch, decoder, branch, close, counters,
        zero_by_counter(), Dict{String,Int}(c => first_event for c in counters), zero_by_counter(), zero_by_counter(),
        Dict{String,Vector{Int}}(), Dict{String,Vector{Int}}(), Set{String}(), 0, 0,
        stats, share, share ? Dict{String,String}(r.counters) : Dict{String,String}(),
        share ? _plan_branch_ids(r) : Dict{String,Tuple{Vector{StreamBasketDesc},Vector{Int}}}(),
        share ? r.seen : nothing, 0, 1:0, share ? WeakRef[WeakRef() for _ in counters] : WeakRef[], 0)
    # All proof containers are fully preallocated here and never grow afterwards (issuance
    # replaces a fixed number of WeakRef slots; release only empties), so this measurement
    # bounds the proof metadata for the whole file. finish_reusable_stream! re-checks it.
    share && (d.proof_reserved = _shared_offsets_proof_bytes(d))
    return d
end

# Plan identity of a branch descriptor: its own basket-descriptor vector and LazyBranch
# fEntry vector, admitted ONLY when both are plain data (Vector{StreamBasketDesc} of
# isbits NamedTuples and Vector{Int}); any other shape is never identified (=> copy).
_plain_branch_identity(br) =
    hasproperty(br, :baskets) && hasproperty(br, :lazy) && hasproperty(br.lazy, :fEntry) &&
    br.baskets isa Vector{StreamBasketDesc} && br.lazy.fEntry isa Vector{Int}
function _plan_branch_ids(r::StreamWindowReader)
    ids = Dict{String,Tuple{Vector{StreamBasketDesc},Vector{Int}}}()
    for (name, br) in r.branches
        _plain_branch_identity(br) && (ids[String(name)] = (br.baskets, br.lazy.fEntry))
    end
    return ids
end
"""True only if `br` is (by identity of its plain baskets and lazy.fEntry arrays) the
planned branch `name` of the reader this state was constructed for."""
function _owner_branch(d::StreamDecodeState, name, br)
    k = String(name)
    haskey(d.branch_ids, k) || return false
    _plain_branch_identity(br) || return false
    b, f = d.branch_ids[k]
    return b === br.baskets && f === br.lazy.fEntry
end

"""
    _proven_window_offsets(d, br, name, range, offsets, window_counters, seen) -> Bool

Opt-in sharing admission, decided before branch state creation. True only when ALL hold:
- d.share_window_offsets;
- `seen` is (===) the seen-set of the reader `d` was constructed for (reader/source owner);
- the ACTUAL branch being decoded, `br`, is that reader's planned branch `name`
  (weak identity of its basket descriptors and LazyBranch fEntry), so a same-schema
  branch of another file/source can never borrow;
- `d` itself issued a complete counter record for its CURRENT window
  (record_window == d.window > 0) and `range` equals that window's range exactly;
- `name` is a planned jagged branch; its counter c comes from d's private plan copy,
  never from the caller;
- `offsets` is identical (===) to the Vector{Int} `d` issued for c in that record;
- the supplied `window_counters` record (a request only, never trusted alone) holds
  that same vector under c.
Anything else (absent record, stale/foreign/unissued/substituted/equal-valued vector,
view, wrong counter, foreign branch) returns false, i.e. the private-copy route. A
cloned wrapper holding the genuine current issued vector under its correct counter is
admitted: vector provenance is authenticated by `d`, not by wrapper identity.
It never relaxes or replaces decoder validation.
"""
function _proven_window_offsets(d::StreamDecodeState, br, name, range, offsets, wc, seen)
    d.share_window_offsets || return false
    (wc !== nothing && offsets isa Vector{Int}) || return false
    owner = d.owner_seen
    (owner !== nothing && owner === seen) || return false
    _owner_branch(d, name, br) || return false
    (d.record_window > 0 && d.record_window == d.window && range == d.record_range) || return false
    c = get(d.branch_counter, String(name), nothing)
    c === nothing && return false
    i = findfirst(==(c), d.counters)
    i === nothing && return false
    d.record_refs[i].value === offsets || return false
    (hasproperty(wc, :offsets) && wc.offsets isa AbstractDict) || return false
    return get(wc.offsets, c, nothing) === offsets
end

"""
    reusable_shared_offsets_charge(d, raw) -> Int

Opt-in only (0 when d.share_window_offsets is false, so default accounting is
unchanged). For every offsets vector THIS state issued for its current window
record, (number of raw Jagged columns aliasing it by ===) x Base.summarysize(o):
the private copies that borrowing replaced, added on top of the deduplicated
Base.summarysize window charge. Vectors not issued by `d` are never charged here.
Equal to the default accounting for exact-capacity records (every
_checked_window_offsets record); a record with spare capacity is overcharged, so an
opt-in run near execution.stream_window_bytes may reject where the default passes
(conservative, never under-counted).
"""
function reusable_shared_offsets_charge(d::StreamDecodeState, raw)
    d.share_window_offsets || return 0
    (d.record_window > 0 && d.record_window == d.window) || return 0
    total = 0
    for ref in d.record_refs
        o = ref.value
        o isa Vector{Int} || continue
        aliases = 0
        for v in values(raw)
            v isa Jagged && v.offsets === o && (aliases += 1)
        end
        aliases == 0 || (total = Base.checked_add(total, Base.checked_mul(aliases, Base.summarysize(o))))
    end
    return total
end

# Proof metadata only: the proof's own containers are charged; issued offsets (weak) and the
# owner plan's already-owned plain arrays (seen-set, basket descriptors, fEntry) are excluded.
# The owner seen-set is NOT measured: Set is an immutable one-field wrapper stored inline in
# a tuple, so a type exclusion of Set never applies and its growing Dict (one entry per
# decoded basket) would be charged (R13 full_ON finding). Its pointer slot is part of the
# fixed StreamDecodeState layout; its storage belongs to the reader.
const _SHARED_PROOF_EXCLUDE = Union{DataType, Core.TypeName, Core.MethodInstance, Vector{Int},
    Vector{StreamBasketDesc}, Set{Tuple{String,Int}}, Dict{Tuple{String,Int},Nothing}}
_shared_offsets_proof_bytes(d::StreamDecodeState) =
    Base.summarysize((d.branch_counter, d.branch_ids, d.record_refs, d.record_range); exclude = _SHARED_PROOF_EXCLUDE)

"""
    reusable_padded_index_reason(branch, baskets; basket_count = UnROOT.numbaskets) -> String

A-only metadata proof for a plan branch with maskable=false (raw fBasketEntry
LONGER than basket count + 1). ROOT's TBranch::Streamer writes fBasketBytes,
fBasketEntry and fBasketSeek with fMaxBaskets = max(fWriteBasket + 1, 10)
entries; unwritten slots stay zero, so a branch with fewer than 9 baskets carries
a zero tail. The ordinary reader conservatively disables masking for that shape
(its check uses the raw array length); that contract is NOT changed here.

The proof re-derives the copied, validated prefix with the unchanged
stream_basket_index (raw branch/LazyBranch.fEntry arrays are never mutated) and
requires ALL of:
- the plan descriptors equal that prefix exactly (lo = starts[ib] + 1,
  hi = starts[ib+1]) with the same per-basket bytes and nonzero seeks;
- the independent writer counter fWriteBasket equals the prefix basket count;
- fBasketBytes/fBasketSeek have the fBasketEntry length and are zero beyond the
  count (no orphan basket record outside the prefix).
Returns "" when proven, otherwise a reason (refusal, never a fallback). A
malformed prefix still throws via stream_basket_index. Per-basket TBasketKey
fNevBuf, offset-trailer and canonical-counter checks in _read_reusable_basket!
remain mandatory and throw on disagreement after admission.
"""
function reusable_padded_index_reason(branch, baskets; basket_count = UnROOT.numbaskets)
    index, reason = stream_basket_index(branch; basket_count)
    isempty(reason) || return reason
    index.maskable && return "not_padded"
    nb = index.count; starts = index.starts
    length(baskets) == nb || return "descriptor_count_mismatch"
    for ib in 1:nb
        bs = baskets[ib]
        (bs.lo == starts[ib] + 1 && bs.hi == starts[ib+1]) || return "descriptor_boundary_mismatch"
    end
    hasproperty(branch, :fWriteBasket) || return "write_basket_count_unavailable"
    wb = branch.fWriteBasket
    (wb isa Integer && !(wb isa Bool) && wb == nb) || return "write_basket_count_mismatch"
    raw = branch.fBasketEntry; bytes = branch.fBasketBytes; seeks = branch.fBasketSeek
    (length(bytes) == length(raw) && length(seeks) == length(raw)) || return "basket_array_length_mismatch"
    for ib in 1:nb
        (bytes[ib] == baskets[ib].bytes && seeks[ib] > 0) || return "basket_record_mismatch"
    end
    (all(iszero, view(bytes, nb+1:length(bytes))) && all(iszero, view(seeks, nb+1:length(seeks)))) ||
        return "nonzero_basket_record_tail"
    return ""
end

"""Metadata-only admission before any Events basket payload read. Returns a reason.

Exact basket indices, or a padded index proven by reusable_padded_index_reason
(read unmasked: every overlapping basket decoded, original values kept); every
jagged branch needs its planned counter; every
counter is a flat non-Bool integer; every planned basket fits the reusable
scratch bound; every branch passes the unchanged reusable-branch admission.
Remaining decoder-only conditions (codec/XZ layout/dictionary) are discovered
per demanded basket and raise WindowedReusableUnsupported, never a fallback.
"""
function reusable_stream_admission(r::StreamWindowReader, d::StreamDecodeState)
    for name in sort!(collect(keys(r.branches)))
        br = r.branches[name]
        if !br.maskable
            why = reusable_padded_index_reason(br.lazy.b, br.baskets)
            isempty(why) || return string("unproven_padded_basket_index:", name, ":", why)
        end
        br.jagged && !haskey(r.counters, name) && return "jagged_branch_without_counter:" * name
        for (ib, bs) in enumerate(br.baskets)
            bs.decoded <= _nanoaod_scratch_limit() || return string("basket_exceeds_reusable_scratch:", name, ":", ib)
        end
        state = d.branch(br.lazy, d.scratch, br.lazy.fEntry, br.E, br.jagged)
        if state === nothing
            # A failed CodecXz/TranscodingStreams version/hash audit is not a branch property.
            d.scratch.audited === false && return "reusable_decode_contract_failed"
            return "reusable_branch_not_admitted:" * name
        end
        d.close(state)
    end
    for c in d.counters
        haskey(r.branches, c) || return "counter_not_planned:" * c
        br = r.branches[c]
        (!br.jagged && br.E <: Integer && br.E !== Bool) || return "invalid_counter_type:" * c
    end
    # Recorded only after the WHOLE admission passes (any refusal leaves no proof).
    for (name, br) in r.branches
        br.maskable || push!(d.padded_proven, String(name))
    end
    return ""
end

"""Extra live bytes charged to EVERY window reservation before Events reads:
persistent scratch capacity, conservative native decoder bound and basket-ID
diagnostic metadata allowance.

`reusable_reservation_bytes(r, d)` is the production entry: identical to the
one-argument result for a default state; with opt-in reusable_shared_offsets it adds
the bounded proof metadata (d.proof_reserved, measured before any Events read) to BOTH
metadata and total, so the pre-work reserve_windowed_selection(extra_bytes = total)
charges it against the SAME configured caps (opt-in reservation >= default). The
basket-ID diagnostic allowance baseline is unchanged."""
function reusable_reservation_bytes(r::StreamWindowReader, d::StreamDecodeState)
    base = reusable_reservation_bytes(r)
    d.share_window_offsets || return base
    d.proof_reserved > 0 || error("internal: reusable shared-offset proof metadata was not measured")
    p = Int128(d.proof_reserved)
    return (scratch = base.scratch, native = base.native, metadata = Base.checked_add(base.metadata, p),
        total = Base.checked_add(base.total, p))
end
function reusable_reservation_bytes(r::StreamWindowReader)
    maxdecoded = 0; baskets = 0
    for br in values(r.branches), bs in br.baskets
        maxdecoded = max(maxdecoded, bs.decoded); baskets += 1
    end
    scratch = Int128(min(maxdecoded, _nanoaod_scratch_limit()))
    native = Int128(_nanoaod_decoder_limit())
    metadata = Base.checked_add(Base.checked_mul(Int128(32), baskets), Base.checked_mul(Int128(8192), length(r.branches) + 1))
    total = Base.checked_add(Base.checked_add(scratch, native), metadata)
    return (scratch = scratch, native = native, metadata = metadata, total = total)
end

function read_reusable_stream_branch(r::StreamWindowReader, d::StreamDecodeState, name, range;
        needed = nothing, offsets = nothing, phase = "pre", basket_observer = (_) -> nothing, window_counters = nothing)
    return read_reusable_branch_owned(r.branches[name], name, range, r.options, r.diagnostics, r.seen, d;
        needed, offsets, phase, basket_observer, window_counters)
end

"""Decode one branch window through the reusable decoder into fresh owned storage.

Jagged branches REQUIRE window-local canonical counter offsets (0-based, n+1);
demanded baskets are validated against them by the unchanged decoder before any
destination write. Flat skipped baskets are zero-filled; jagged skipped content
remains zero, exactly like the legacy masked window route.

A proven padded (maskable=false) branch keeps the ORIGINAL unmasked contract of
read_stream_branch_owned/read_nanoaod_branch: needed is ignored and every
overlapping basket is decoded. Jagged padded branches still use canonical
offsets, which the decoder checks per entry against each basket's offset
trailer, so the output equals the basket-reconstructed arrays or the read throws.

Jagged output offsets are a private copy of the canonical offsets, except with
opt-in d.share_window_offsets when _proven_window_offsets proves (before branch
state creation) that `offsets` is the vector THIS state issued for the branch's
planned counter in its CURRENT window record: then the output BORROWS that vector
(same values; the replaced copy is charged by reusable_shared_offsets_charge).
Borrowed offsets are shared with the record and all siblings and must never be
mutated or resized by any caller for their whole reachable lifetime; mutate only a
private copy. Content is always freshly allocated.
"""
function read_reusable_branch_owned(br, name, range, options, diagnostics, seen, d::StreamDecodeState;
        needed = nothing, offsets = nothing, phase = "pre", basket_observer = (_) -> nothing, window_counters = nothing)
    if !br.maskable
        String(name) in d.padded_proven ||
            throw(WindowedReusableUnsupported(String(name), "unproven_padded_basket_index"))
        needed = nothing
    end
    n = length(range)
    needed === nothing || length(needed) == n || error("stream mask length mismatch")
    E = br.E
    if br.jagged
        offsets === nothing && throw(WindowedReusableUnsupported(String(name), "jagged_branch_without_counter"))
        (length(offsets) == n + 1 && first(offsets) == 0 && issorted(offsets)) || error("invalid canonical stream offsets")
        Int128(last(offsets)) * sizeof(E) + 8Int128(n + 1) > options.stream_window_bytes &&
            error("stream canonical offsets exceed window budget")
        declared = sum((Int128(br.baskets[ib].decoded) for ib in stream_basket_overlap(br.baskets, range)); init = Int128(0))
        Int128(last(offsets)) * sizeof(E) <= declared || error("stream canonical offsets exceed declared basket payload")
    else
        offsets === nothing || error("internal: flat reusable branch received canonical offsets: $name")
    end
    share = br.jagged && _proven_window_offsets(d, br, name, range, offsets, window_counters, seen)
    state = d.branch(br.lazy, d.scratch, br.lazy.fEntry, E, br.jagged)
    state === nothing && throw(WindowedReusableUnsupported(String(name), "reusable_branch_not_admitted"))
    d.live_states += 1
    try
        data = br.jagged ? zeros(E, last(offsets)) : Vector{E}(undef, n)
        outoffsets = br.jagged ? (share ? offsets : copy(offsets)) : Int[]
        copied = share ? 0 : sizeof(outoffsets)
        d.stats["destination_allocated_bytes"] += sizeof(data) + copied
        d.stats["offset_copy_bytes"] += copied
        if share
            d.stats["shared_offset_aliases"] += 1
            d.stats["avoided_offset_copy_bytes"] += sizeof(offsets)
        end
        _reusable_basket_loop!(data, br, String(name), range, needed, offsets, String(phase), diagnostics, seen, d, state, basket_observer)
        return br.jagged ? Jagged(data, outoffsets) : data
    finally
        try
            d.close(state)
        finally
            d.live_states -= 1
        end
    end
end

# Function barrier: specialized on the concrete destination Vector{E}.
function _reusable_basket_loop!(data::Vector{E}, br, name::String, range, needed, offsets, phase::String,
        diagnostics, seen, d::StreamDecodeState, state, basket_observer) where {E}
    jagged = br.jagged
    for ib in stream_basket_overlap(br.baskets, range)
        bs = br.baskets[ib]
        first(range) <= bs.lo <= bs.hi <= last(range) || error("stream read splits basket")
        lo = bs.lo - first(range) + 1; hi = bs.hi - first(range) + 1
        skip = needed !== nothing && !any(view(needed, lo:hi))
        action = skip ? "skipped" : "decoded"
        for (suffix, value) in (("baskets", 1), ("compressed_bytes", bs.bytes),
                ("compressed_payload_bytes", bs.bytes - bs.keylen), ("declared_decoded_bytes", bs.decoded))
            key = string(phase, "_", action, "_", suffix); diagnostics[key] = get(diagnostics, key, 0) + value
        end
        basket_observer((phase = phase, name = name, basket = ib, decoded = !skip,
            compressed_bytes = bs.bytes, compressed_payload_bytes = bs.bytes - bs.keylen, declared_decoded_bytes = bs.decoded))
        if skip
            jagged || fill!(view(data, lo:hi), zero(E))
            push!(get!(Vector{Int}, d.skipped_ids, name), ib)
            d.stats["skipped_baskets"] += 1
            continue
        end
        token = (name, ib)
        if token in seen
            diagnostics["repeated_baskets"] = get(diagnostics, "repeated_baskets", 0) + 1
            d.stats["duplicate_basket_decodes"] += 1
        else
            diagnostics["unique_baskets"] = get(diagnostics, "unique_baskets", 0) + 1
            push!(seen, token)
        end
        entries = hi - lo + 1
        if jagged
            dst = offsets[lo]; m = offsets[hi+1] - dst
            ok = d.decoder(data, dst, br.lazy, ib, state, entries; canonical = offsets, lo = lo)
        else
            dst = lo - 1; m = entries
            ok = d.decoder(data, dst, br.lazy, ib, state, entries)
        end
        ok isa Bool || error("reusable decoder returned a non-Bool admission for $name basket $ib")
        ok || throw(WindowedReusableUnsupported(string(name, " basket ", ib), "reusable_decoder_declined_demanded_basket"))
        push!(get!(Vector{Int}, d.decoded_ids, name), ib)
        s = d.stats
        if !br.maskable
            # Same subset keys as read_stream_branch_owned (also counted in phase totals).
            diagnostics["padded_decoded_baskets"] = get(diagnostics, "padded_decoded_baskets", 0) + 1
            diagnostics["padded_decoded_compressed_bytes"] = get(diagnostics, "padded_decoded_compressed_bytes", 0) + bs.bytes
            diagnostics["padded_decoded_declared_bytes"] = get(diagnostics, "padded_decoded_declared_bytes", 0) + bs.decoded
            s["padded_decoded_baskets"] += 1
        end
        s["decoded_baskets"] += 1
        s["decoded_declared_bytes"] += bs.decoded
        s["destination_bytes"] += m * sizeof(E)
        cap = length(d.scratch.raw)
        cap <= _nanoaod_scratch_limit() || error("reusable decoder scratch exceeds its bound")
        s["scratch_capacity_highwater_bytes"] = max(s["scratch_capacity_highwater_bytes"], cap)
    end
    return nothing
end

"""Typed barrier: ordinary _nanoaod_counter_offsets semantics on one window.

Window-local offsets start at zero; negative and overflow checks use the
file-cumulative base and report the ORIGINAL 1-based event with the same
ArgumentError messages as the ordinary full-file reader. Every row is checked,
including rows later rejected by cuts.
"""
function _checked_window_offsets(counts::AbstractVector, base::Int, first_event::Int, counter::String)
    n = length(counts)
    out = Vector{Int}(undef, n + 1)
    out[1] = 0
    _checked_window_offsets!(out, counts, base, first_event, counter)
    return out
end
function _checked_window_offsets!(out::Vector{Int}, counts::AbstractVector{T}, base::Int, first_event::Int,
        counter::String) where {T}
    for i in 1:length(counts)
        count = Int(counts[i])
        count >= 0 || throw(ArgumentError("negative collection count in $counter at event $(first_event + i - 1)"))
        count <= typemax(Int) - (base + out[i]) ||
            throw(ArgumentError("collection offsets overflow in $counter at event $(first_event + i - 1)"))
        out[i+1] = out[i] + count
    end
    return nothing
end

"""Decode and check every planned counter exactly once for window k, all rows,
before any payload of that window. Enforces strictly ascending contiguous
windows (next expected event) and advances the checked cumulative totals."""
function reusable_window_counters!(r::StreamWindowReader, d::StreamDecodeState, k; basket_observer = (_) -> nothing)
    range = r.windows[k]
    d.window == k - 1 || error("reusable decoder window order drift: expected window $(d.window + 1), got $k")
    # Opt-in proof: nothing is shareable until this window's record is complete.
    d.share_window_offsets && (d.record_window = 0)
    counts = Dict{String,Any}(); offsets = Dict{String,Vector{Int}}()
    for c in d.counters
        d.counter_next[c] == first(range) ||
            error("reusable counter $c expected event $(d.counter_next[c]) but window $k starts at $(first(range))")
        d.counter_window[c] == k - 1 || error("reusable counter $c validated twice or out of window order")
        v = read_reusable_stream_branch(r, d, c, range; phase = c in r.pre ? "pre" : "counter", basket_observer)
        length(v) == length(range) || error("reusable counter $c window length mismatch")
        o = _checked_window_offsets(v, d.counter_base[c], first(range), c)
        d.counter_base[c] = Base.checked_add(d.counter_base[c], last(o))
        d.counter_next[c] = first(range) + length(range)
        d.counter_window[c] = k
        counts[c] = v; offsets[c] = o
    end
    d.window = k
    # Opt-in proof, issued only for the reader this state was constructed for AND only when
    # every counter was decoded from that reader's own planned counter branch (else copies).
    if d.share_window_offsets && d.owner_seen !== nothing && d.owner_seen === r.seen &&
            all(c -> haskey(r.branches, c) && _owner_branch(d, c, r.branches[c]), d.counters)
        for (i, c) in enumerate(d.counters)
            d.record_refs[i] = WeakRef(offsets[c])
        end
        d.record_range = range
        d.record_window = k
    end
    return (counts = counts, offsets = offsets)
end

"""Shared read-only canonical offsets for jagged name (nothing for flat)."""
function reusable_canonical_offsets(r::StreamWindowReader, d::StreamDecodeState, wc, name)
    r.branches[name].jagged || return nothing
    c = get(r.counters, name, nothing)
    c === nothing && throw(WindowedReusableUnsupported(String(name), "jagged_branch_without_counter"))
    o = get(wc.offsets, c, nothing)
    o === nothing && error("reusable counter $c not validated for this window")
    d.sibling_reuses[c] += 1
    return o
end

"""Owned raw/progress bytes plus scratch capacity plus the conservative native
decoder bound must fit the window budget; records the measured high-water."""
function check_reusable_window_memory!(d::StreamDecodeState, options, owned)
    live = Int128(owned) + length(d.scratch.raw) + _nanoaod_decoder_limit()
    live <= options.stream_window_bytes || error("windowed reusable decoder live bytes $live (owned raw/progress + scratch capacity + native decoder bound) exceed execution.stream_window_bytes=$(options.stream_window_bytes)")
    d.stats["live_highwater_bytes"] = max(d.stats["live_highwater_bytes"], Int(live))
    d.stats["owned_window_highwater_bytes"] = max(d.stats["owned_window_highwater_bytes"], Int(owned))
    return nothing
end

"""Final coverage proof and diagnostics. Throws on any incomplete coverage."""
function finish_reusable_stream!(r::StreamWindowReader, d::StreamDecodeState, n::Integer; reserved_extra = nothing)
    d.live_states == 0 || error("reusable decoder native state still live at file end")
    d.window == length(r.windows) || error("reusable decoder did not visit every window")
    expected = 1
    for w in r.windows
        first(w) == expected || error("reusable decoder window coverage gap")
        expected = first(w) + length(w)
    end
    expected == n + 1 || error("reusable decoder window coverage mismatch")
    for c in d.counters
        d.counter_next[c] == n + 1 && d.counter_window[c] == length(r.windows) ||
            error("reusable counter $c final coverage mismatch")
    end
    # Padded branches: proven at admission and every covered basket decoded
    # (key/entry-checked) through the modern decoder; none skipped.
    padded = sort!([String(name) for (name, br) in r.branches if !br.maskable])
    for name in padded
        name in d.padded_proven || error("reusable padded branch $name was not proven at admission")
        isempty(get(d.skipped_ids, name, Int[])) || error("reusable padded branch $name skipped a basket")
        sort!(unique(get(d.decoded_ids, name, Int[]))) == collect(stream_basket_overlap(r.branches[name].baskets, 1:n)) ||
            error("reusable padded branch $name basket coverage mismatch")
    end
    s = d.stats
    allowance = reserved_extra === nothing ? nothing : reserved_extra.metadata
    idbytes = Base.summarysize((d.decoded_ids, d.skipped_ids))
    allowance === nothing || idbytes <= allowance || error("reusable decoder diagnostics exceed reserved metadata allowance")
    proofbytes = d.share_window_offsets ? _shared_offsets_proof_bytes(d) : 0
    if d.share_window_offsets
        # Opt-in proof metadata was reserved before any Events read (reusable_reservation_bytes(r, d)):
        # the measured proof must stay within that pre-work bound, and diagnostic IDs within the
        # unchanged baseline allowance (fully reserved metadata minus the proof reservation).
        proofbytes <= d.proof_reserved ||
            error("reusable shared-offset proof metadata exceeds its pre-work reservation")
        allowance === nothing || idbytes + proofbytes <= allowance ||
            error("reusable shared-offset proof metadata exceeds reserved metadata allowance")
        allowance === nothing || idbytes <= allowance - d.proof_reserved ||
            error("reusable decoder diagnostics exceed reserved metadata allowance")
    end
    out = Dict{String,Any}(
        "windowed_reusable_decoder_requested" => true, "windowed_reusable_decoder_effective" => true,
        "requested_reader_engine" => "reusable_decoder_window_owned_copy",
        "reader_engine" => "reusable_decoder_window_owned_copy", "reusable_decoder" => true,
        "reusable_policy" => "modern_only_no_legacy_fallback", "reusable_admission_reason" => "",
        "reusable_admitted_branches" => sort!(collect(keys(r.branches))),
        "reusable_fallback_baskets" => 0, "legacy_decoded_baskets" => 0,
        "reusable_decoded_baskets" => s["decoded_baskets"], "reusable_skipped_baskets" => s["skipped_baskets"],
        "reusable_branch_decoded_basket_ids" => Dict(k => copy(v) for (k, v) in d.decoded_ids),
        "reusable_branch_skipped_basket_ids" => Dict(k => copy(v) for (k, v) in d.skipped_ids),
        "reusable_duplicate_basket_decodes" => s["duplicate_basket_decodes"],
        "reusable_decoded_declared_bytes" => s["decoded_declared_bytes"],
        "reusable_destination_bytes" => s["destination_bytes"],
        "reusable_destination_allocated_bytes" => s["destination_allocated_bytes"],
        "reusable_offset_copy_bytes" => s["offset_copy_bytes"],
        "reusable_scratch_limit_bytes" => _nanoaod_scratch_limit(),
        "reusable_scratch_capacity_highwater_bytes" => s["scratch_capacity_highwater_bytes"],
        "reusable_native_decoder_limit_bytes" => _nanoaod_decoder_limit(),
        "reusable_live_highwater_bytes" => s["live_highwater_bytes"],
        "reusable_owned_window_highwater_bytes" => s["owned_window_highwater_bytes"],
        "reusable_live_within_bound" => s["live_highwater_bytes"] <= r.options.stream_window_bytes,
        "reusable_retained_table_highwater_bytes" => s["retained_table_highwater_bytes"],
        "reusable_reserved_extra_bytes" => reserved_extra === nothing ? 0 : Int(reserved_extra.total),
        "reusable_diagnostic_id_bytes" => idbytes,
        "reusable_counter_names" => copy(d.counters),
        "reusable_counter_windows_checked" => copy(d.counter_window),
        "reusable_counter_sibling_reuses" => copy(d.sibling_reuses),
        "reusable_counter_final_totals" => copy(d.counter_base),
        "reusable_padded_branches" => padded,
        "reusable_padded_decoded_baskets" => s["padded_decoded_baskets"],
        "reusable_padded_index_policy" => "validated_prefix_unmasked_modern_decode",
        "full_file_raw_destination" => false, "full_file_counter_prefix" => false,
        "retained_selected_file_table" => true)
    # Keys only when requested: the default diagnostics record is unchanged.
    if d.share_window_offsets
        out["reusable_shared_window_offsets"] = true
        out["reusable_shared_offset_aliases"] = s["shared_offset_aliases"]
        out["reusable_avoided_offset_copy_bytes"] = s["avoided_offset_copy_bytes"]
        out["reusable_shared_offset_accounting"] = "charged_as_private_copy_exact_capacity_else_conservative"
        out["reusable_shared_offset_proof"] = "per_state_current_window_weak_record_planned_counter_owner_branch"
        out["reusable_shared_offset_proof_bytes"] = proofbytes
        out["reusable_shared_offset_borrow_contract"] = "read_only_offsets_never_mutate_or_resize"
    end
    return out
end

"""
    stream_window_prefix(r, m) -> StreamWindowReader

Bounded lower seam for diagnostics: the first `m` planned common-boundary
windows of `r` (which must start at event 1), with fresh reader-owned
diagnostics and basket-seen set. Shares only read-only plan metadata (branch
descriptors/LazyBranch) and the borrowed source; the caller still owns source
lifetime. Production whole-file runs never call it.
"""
function stream_window_prefix(r::StreamWindowReader, m::Integer)
    (!(m isa Bool) && 1 <= m <= length(r.windows)) ||
        throw(ArgumentError("window prefix $m outside 1:$(length(r.windows))"))
    first(first(r.windows)) == 1 || error("window prefix requires a plan starting at event 1")
    diag = deepcopy(r.diagnostics)
    diag["window_prefix_limit"] = Int(m)
    diag["window_prefix_events"] = last(r.windows[m])
    diag["window_prefix_source_windows"] = length(r.windows)
    return StreamWindowReader(r.source, r.branches, copy(r.pre), copy(r.post), copy(r.counters),
        r.windows[1:m], r.charges[1:m], r.options, diag, Set{Tuple{String,Int}}())
end

"""Drop persistent scratch and any opt-in sharing proof. Native states are already
finalized per branch. Outputs already returned keep their own (borrowed) offsets."""
function release_reusable_stream!(d::StreamDecodeState)
    d.scratch.raw = UInt8[]
    d.record_window = 0
    for i in eachindex(d.record_refs)
        d.record_refs[i] = WeakRef()
    end
    d.owner_seen = nothing
    empty!(d.branch_ids)
    return nothing
end
