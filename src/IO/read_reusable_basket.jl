# Returns false only before touching destination. Once admitted, corrupt data
# throws; no catch-and-fallback may hide checksum/layout errors.
function _read_reusable_basket!(dest::Vector{E}, dst, lb, ib, state, entries;
                                canonical = nothing, lo = 1) where {E}
    state === nothing && return false
    b = lb.b; mapped = lb.f.fobj.mmap_ary
    pos = Int(b.fBasketSeek[ib]); bytes = Int(b.fBasketBytes[ib])
    pos == 0 && return false # recovered baskets remain upstream's responsibility
    bytes >= 16 && pos >= 0 && Int128(pos)+bytes <= length(mapped) || error("basket outside mapped source")
    header = IOBuffer(UnROOT.read_seek_nb(lb.f.fobj, pos, 16))
    declared = Int(UnROOT.readtype(header, Int32)); version = UnROOT.readtype(header, Int16)
    decoded = Int(UnROOT.readtype(header, Int32)); UnROOT.readtype(header, UInt32)
    keylen = Int(UnROOT.readtype(header, Int16))
    declared == bytes && 16 <= keylen <= min(bytes, 65536) && decoded >= 0 && version > 0 || error("invalid basket key")
    key = UnROOT.unpack(UnROOT.OffsetBuffer(IOBuffer(UnROOT.read_seek_nb(lb.f.fobj, pos, keylen)), pos), UnROOT.TBasketKey)
    key.fNbytes == bytes && key.fKeylen == keylen && key.fObjlen == decoded &&
        key.fNevBuf == entries && key.fSeekKey == pos && key.fClassName == "TBasket" || error("basket key/index mismatch")
    content = Int(key.fLast)-keylen
    0 <= content <= decoded || error("invalid basket content boundary")
    trailer = decoded-content
    (trailer == 0 || (trailer >= 8 && (trailer-8) % 4 == 0 && (trailer-8) ÷ 4 == entries)) || error("invalid basket offset table size")
    canonical !== nothing && trailer == 0 && return false
    decoded <= _nanoaod_scratch_limit() || return false
    payload = view(mapped, pos+keylen+1:pos+bytes)
    compressed = UnROOT.iscompressed(key)
    blocks = compressed ? validate_decode_blocks(payload, decoded) : ()
    blocks === nothing && return false
    # Unknown/no-check XZ streams retain the historical reader. Supported checks
    # are required before entering our native path. Dictionary requirements
    # above the native budget are also unsupported, not corruption.
    for (q,c,d) in blocks
        # Memory admission examines one XZ block only. Multi-block XZ streams
        # remain upstream; otherwise a later block could request a larger dict.
        footer = q+c-12
        backward = sum(UInt64(payload[footer+4+i]) << (8i) for i in 0:3)
        index = footer-Int(4*(backward+1))
        payload[index+1] == 0x01 || return false
        payload[q+6] == 0 && payload[q+7] in (0x01, 0x04, 0x0a) || return false
        # Admit only the regular single LZMA2 filter header used by ROOT XZ.
        h = q+12
        h+3 <= q+c-13 || error("truncated XZ block header")
        headerbytes = (Int(payload[h])+1)*4
        headerbytes >= 8 && h+headerbytes <= q+c-12 || error("invalid XZ block header size")
        payload[h+1] == 0 && payload[h+2] == 0x21 && payload[h+3] == 1 || return false
        h+4 < h+headerbytes-4 || error("truncated LZMA2 properties")
        prop = Int(payload[h+4])
        prop <= 40 || error("invalid LZMA2 dictionary property")
        dictionary = prop == 40 ? Int128(0xffffffff) : Int128(2 | (prop & 1)) << (prop ÷ 2 + 11)
        dictionary + 1024^2 <= _nanoaod_decoder_limit() || return false
    end
    compressed || length(payload) == decoded || error("uncompressed basket length mismatch")
    # Exact-size replacement when growing avoids Vector's geometric overgrowth;
    # otherwise keep capacity across baskets and columns (never shrink/reallocate).
    scratch = state.scratch
    length(scratch.raw) < decoded && (scratch.raw = Vector{UInt8}(undef, decoded))
    raw = scratch.raw
    if compressed
        base = 0
        for (q,c,d) in blocks
            _decode_xz_window!(raw, mapped, pos+keylen+q, c, base, d, state)
            base += d
        end
        base == decoded || error("decoded basket length mismatch")
        validate_decode_checksum(view(raw, 1:decoded), payload, blocks)
    else
        copyto!(raw, 1, mapped, pos+keylen+1, decoded)
    end
    # Read offsets without allocating or retaining a second offsets array.
    # ROOT stores n starts after a four-byte prefix and a final four-byte word.
    # Function barrier (2026-11-10): the basket key/index values above come from untyped UnROOT
    # branch/file fields, so this per-entry loop runs in a helper specialized on the
    # concrete runtime argument types. Every check is unchanged.
    _validate_basket_offsets(raw, content, keylen, trailer, entries, canonical, lo, E)
    m = content ÷ sizeof(E)
    content % sizeof(E) == 0 || error("primitive basket content size mismatch")
    if canonical === nothing
        m == entries || error("flat basket primitive length mismatch")
    else
        m == canonical[lo+entries]-canonical[lo] || error("basket content disagrees with canonical counter")
    end
    0 <= dst <= length(dest) && m <= length(dest)-dst || error("basket destination bounds mismatch")
    # Validate Bool representations before reinterpretation/writes.
    E === Bool && !all(x -> x <= 0x01, view(raw, 1:content)) && error("invalid primitive Bool encoding")
    _copy_primitive_endian!(dest, dst, raw, content)
    return true
end

"""
    _validate_basket_offsets(raw, content, keylen, trailer, entries, canonical, lo, ::Type{E})

Per-entry ROOT basket offset validation for `_read_reusable_basket!`: zero start,
monotonic bounds, element alignment and (when `canonical !== nothing`) agreement with
the canonical counter offsets. Throws on the first violation; validates nothing when
`trailer == 0`. Kept as a separate method so the loop specializes on concrete argument
types instead of inheriting the caller's untyped basket metadata.
"""
function _validate_basket_offsets(raw, content, keylen, trailer, entries, canonical, lo, ::Type{E}) where {E}
    previous = 0
    for k in 1:(trailer == 0 ? 0 : entries)
        off = Int(UnROOT.ntoh(reinterpret(Int32, view(raw, content+4k+1:content+4k+4))[1]))-keylen
        0 <= off <= content && off >= previous || error("invalid basket offsets")
        k == 1 && off != 0 && error("basket offsets do not start at zero")
        off % sizeof(E) == 0 || error("unaligned primitive basket offset")
        if canonical !== nothing
            Int128(off) == Int128(canonical[lo+k-1]-canonical[lo])*sizeof(E) || error("basket offsets disagree with canonical counter")
        end
        previous = off
    end
    return nothing
end

function _copy_primitive_endian!(dest::Vector{E}, dst, raw, content) where {E}
    values = reinterpret(E, view(raw, 1:content))
    for k in eachindex(values)
        dest[dst+k] = UnROOT.ntoh(values[k])
    end
    return nothing
end
