"""Decode exclusively owned bytes. This function receives no source or ROOT object."""
function decode_prepared_basket(job)
    job.J in (UnROOT.Nojagg,UnROOT.Nooffsetjagg) || error("unsupported detached interpretation")
    key = job.key; bytes = job.bytes
    bytes isa Vector{UInt8} || error("decoder requires owned compressed Vector")
    length(bytes) == key.fNbytes-key.fKeylen || error("compressed payload length mismatch")
    blocks = UnROOT.iscompressed(key) ? validate_decode_blocks(bytes, key.fObjlen) : ()
    blocks === nothing && error("unsupported codec after admission")
    blocks == job.blocks || error("compression descriptor changed")
    raw = UnROOT.decompress_datastreambytes(bytes, key)
    length(raw) == key.fObjlen || error("decoded basket length mismatch")
    isempty(blocks) || validate_decode_checksum(raw, bytes, blocks)
    content = Int(key.fLast-key.fKeylen)
    0 <= content <= length(raw) || error("invalid decoded content boundary")
    n = job.entries
    trailer = length(raw)-content
    offsets = Int32[]
    if trailer > 0
        trailer >= 8 && (trailer-8) % 4 == 0 && (trailer-8) ÷ 4 == n || error("invalid decoded offset table length")
        offbytes = view(raw, content+5:length(raw)-4)
        offsets = ntoh.(reinterpret(Int32, offbytes)) .- key.fKeylen
        push!(offsets, Int32(content))
        length(offsets) == n+1 && first(offsets) == 0 && issorted(offsets) && last(offsets) == content || error("invalid decoded basket offsets")
    end
    if job.J === UnROOT.Nojagg
        content == Int128(n)*sizeof(job.T) || error("flat basket primitive length mismatch")
    else
        length(offsets) == n+1 || error("jagged basket missing offsets")
        size = sizeof(eltype(job.T))
        header = 0 # Only regular primitive Nooffsetjagg is admitted.
        for i in 1:n
            len = Int(offsets[i+1]-offsets[i])
            (len == 0 || (len >= header && (len-header) % size == 0)) || error("invalid primitive jagged event length")
        end
    end
    resize!(raw, content)
    return interpret_decoded_basket(raw, offsets, job.T, job.J, n)
end

# Type values come from heterogeneous producer plans. Dispatch once here so the
# primitive conversion is inferred without specializing the queue or its jobs.
function interpret_decoded_basket(raw, offsets, ::Type{T}, ::Type{J}, n) where {T,J}
    result = UnROOT.interped_data(raw, offsets, T, J)
    length(result) == n || error("interpreted basket entry count mismatch")
    return result
end
