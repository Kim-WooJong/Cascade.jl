"""Prepare the complete phase before dispatch. Only producer-owned metadata is read.

Unsupported encodings return a reason; malformed supported input throws. Plans
contain basket descriptors, not copies of compressed payloads or final columns.
"""
function prepare_nanoaod_decode(src::NanoAODSource, names, needed, diagnostics; max_bytes)
    jobs = column_read_jobs(src, names, needed, diagnostics)
    plans = Any[]; descriptors = Any[]
    for (name, offsets) in jobs
        b = src.file[string(src.tree, "/", name)]
        ismissing(b) && error("missing branch: $name")
        b isa UnROOT.TBranch || return nothing, "unsupported_interpretation"
        length(b.fLeaves.elements) == 1 || return nothing, "unsupported_multi_leaf"
        T, J = UnROOT.auto_T_JaggT(src.file, b; customstructs = src.file.customstructs)
        jagged = T <: AbstractVector
        E = jagged ? eltype(T) : T
        E in (Bool, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64) ||
            return nothing, "unsupported_primitive"
        decode_interpretation_supported(b,T,J) ||
            return nothing, "unsupported_interpretation"
        n = Int(length(b)); n == nevents(src) || error("branch event length mismatch: $name")
        nb = UnROOT.numbaskets(b); starts = b.fBasketEntry
        length(starts) == nb + 1 && starts[1] == 0 && starts[end] == n && issorted(starts) ||
            return nothing, "unsupported_basket_index"
        needed === nothing || length(needed) == n || throw(ArgumentError("needed mask length mismatch"))
        masked = jagged && needed !== nothing && offsets !== nothing
        masked && length(offsets) != n + 1 && error("canonical offsets length mismatch: $name")
        push!(plans, (name = name, T = T, J = J, E = E, jagged = jagged, masked = masked,
            offsets = offsets, n = n))
        for ib in 1:nb
            lo = Int(starts[ib]) + 1; hi = Int(starts[ib+1]); entries = hi-lo+1
            skip = (!jagged || masked) && _skip(needed, starts, ib)
            if skip
                push!(descriptors, (branch = length(plans), basket = ib, lo = lo, hi = hi,
                    skip = true, charge = 0, pos = 0, key = nothing, blocks = (), compressed = 0))
                continue
            end
            pos = Int(b.fBasketSeek[ib]); bytes = Int(b.fBasketBytes[ib])
            pos == 0 && return nothing, "recovered_basket"
            bytes >= 16 && pos >= 0 && Int128(pos) + bytes <= length(src.file.fobj.mmap_ary) || error("basket outside mapped source: $name/$ib")
            first16 = IOBuffer(UnROOT.read_seek_nb(src.file.fobj, pos, 16))
            declared = Int(UnROOT.readtype(first16, Int32)); version = UnROOT.readtype(first16, Int16)
            decoded = Int(UnROOT.readtype(first16, Int32)); UnROOT.readtype(first16, UInt32)
            keylen = Int(UnROOT.readtype(first16, Int16))
            declared == bytes && 16 <= keylen <= min(bytes, 65536) && decoded >= 0 && version > 0 || error("invalid basket key: $name/$ib")
            # Header staging is small, independently bounded metadata. Payload staging
            # below is credited before its first allocation.
            key = UnROOT.unpack(UnROOT.OffsetBuffer(IOBuffer(UnROOT.read_seek_nb(src.file.fobj, pos, keylen)), pos), UnROOT.TBasketKey)
            key.fNbytes == bytes && key.fKeylen == keylen && key.fObjlen == decoded && key.fNevBuf == entries &&
                key.fSeekKey == pos && key.fClassName == "TBasket" || error("basket key/index mismatch: $name/$ib")
            content = Int(key.fLast) - keylen
            0 <= content <= decoded || error("invalid basket content length: $name/$ib")
            trailer = decoded - content
            (trailer == 0 || (trailer >= 8 && (trailer-8) % 4 == 0 && (trailer-8) ÷ 4 == entries)) || error("invalid basket offset table size: $name/$ib")
            jagged && trailer == 0 && return nothing, "unsupported_missing_offsets"
            c = bytes-keylen
            compressed = view(src.file.fobj.mmap_ary, pos+keylen+1:pos+bytes)
            blocks = UnROOT.iscompressed(key) ? validate_decode_blocks(compressed, decoded) : ()
            blocks === nothing && return nothing, "unsupported_compression"
            # Conservative accounted array payload: staging/block copies, decoded
            # and interpreted bytes, intermediate/final offsets. Not allocator/RSS.
            charge128 = 3Int128(c) + 3Int128(decoded) + 16Int128(entries+1)
            charge128 <= max_bytes || error("basket reservation exceeds decode_queue_bytes: $name/$ib")
            push!(descriptors, (branch = length(plans), basket = ib, lo = lo, hi = hi,
                skip = false, charge = Int(charge128), pos = pos+keylen,
                key = key, blocks = blocks, compressed = c))
        end
    end
    return (plans = plans, descriptors = descriptors), ""
end
