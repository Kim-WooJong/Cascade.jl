"""Bounded, serial-file-task-owned identity ledger. No payload references survive a check.

Only the reusable buffer route's plain Vector/Jagged/counter graph is admitted.
Container/header allowance is intentionally conservative; Julia 1.11/1.12 Vector
backing storage is charged through its Memory (including spare capacity). No
Base.SummarySize internal traversal or Any-valued memo is used.
"""
mutable struct WindowAccounting
    identities::Vector{UInt}
    used::Int
    reserved_bytes::Int
    checks::Int
    max_charge::Int
end
function WindowAccounting(slots::Int)
    slots >= 0 || throw(ArgumentError("negative accounting slots"))
    reserved = Base.checked_add(Base.checked_mul(2sizeof(UInt), slots), 4096)
    ids = zeros(UInt, slots)
    return WindowAccounting(ids, 0, reserved, 0, 0)
end
# Backing addresses deduplicate live rooted payloads; headers are conservatively recharged.
function _account_memory!(w::WindowAccounting, a::Vector{T}) where {T}
    isprimitivetype(T) && sizeof(T) > 0 || error("reusable accounting unsupported vector element type: $T")
    m = a.ref.mem
    id = UInt(pointer_from_objref(m))
    for i in 1:w.used
        w.identities[i] == id && return 64
    end
    w.used < length(w.identities) || error("reusable accounting identity bound exceeded")
    w.used += 1; w.identities[w.used] = id
    return Base.checked_add(80, Base.checked_mul(length(m), sizeof(T)))
end
_account_column!(w, a::Vector) = _account_memory!(w, a)
function _account_column!(w, a::EventIO.Jagged)
    return Base.checked_add(32, Base.checked_add(_account_memory!(w,a.content), _account_memory!(w,a.offsets)))
end
_account_column!(w, a) = error("reusable accounting unsupported column: $(typeof(a))")
# Dict storage uses primitive control bytes plus keys/vals pointer Memory. Charge
# allocated slots, not entries; keys have their own byte charge. These stores are
# small, so a deliberately generous 4KiB/header + 64B/slot avoids private layout.
function _account_dict!(w, d::Dict{String})
    total = Base.checked_add(4096, Base.checked_mul(64, length(d.slots)))
    for (k,v) in d
        total = Base.checked_add(total, Base.checked_add(16, sizeof(k)))
        total = Base.checked_add(total, _account_column!(w,v))
    end
    return total
end
function accounting_window_bytes!(w::WindowAccounting, raw::Dict{String,Any}, progress, counters, needed, pool)
    pool === nothing && error("reusable accounting requires reuse_window_buffers")
    progress === pool.progress || error("reusable accounting progress owner mismatch")
    progress.memo === nothing || error("reusable accounting does not support variable memo")
    VERSION >= v"1.11" && VERSION < v"1.13" || error("reusable accounting supports Julia 1.11/1.12 only")
    w.used = 0
    # Full workspace capacity is charged, and its integer-only ledger retains no raw.
    total = Base.checked_add(pool.reserved_bytes, w.reserved_bytes)
    try
        total = Base.checked_add(total, _account_dict!(w,raw))
        total = Base.checked_add(total, _account_dict!(w,progress.offsets))
        if counters !== nothing
            counters isa NamedTuple{(:counts,:offsets)} || error("reusable accounting unsupported counter record")
            total = Base.checked_add(total, 32)
            total = Base.checked_add(total, _account_dict!(w,counters.counts))
            total = Base.checked_add(total, _account_dict!(w,counters.offsets))
        end
        needed === nothing || (total = Base.checked_add(total, _account_column!(w,needed)))
        w.checks += 1; w.max_charge = max(w.max_charge,total)
        return total
    finally
        w.used = 0
    end
end
