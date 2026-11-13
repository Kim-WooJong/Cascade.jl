"""Check the single XZ stream index against ROOT's declared output length.

The upstream XZ broadcast can otherwise repeat a one-byte transcode result
into a larger declared slice. Parse lengths before calling it; native transcode
still checks stream/CRC integrity. No decompression or native allocation here.
"""
function validate_decode_xz_index(bytes, q, c, declared)
    c >= 24 && q >= 1 && q+c-1 <= length(bytes) || error("truncated XZ stream")
    footer = q+c-12
    bytes[footer+10] == 0x59 && bytes[footer+11] == 0x5a || error("invalid XZ footer")
    bytes[q+6] == bytes[footer+8] && bytes[q+7] == bytes[footer+9] || error("XZ stream flags disagree")
    backward = UInt64(0)
    for i in 0:3; backward |= UInt64(bytes[footer+4+i]) << (8i); end
    indexbytes = 4Int128(backward+1)
    indexbytes <= footer-q-12 || error("XZ index outside stream")
    start = footer-Int(indexbytes)
    bytes[start] == 0 || error("invalid XZ index indicator")
    limit = footer-4 # first CRC byte; variable integers must finish before it
    integer = function(p)
        value = UInt64(0)
        for k in 0:8
            p < limit || error("truncated XZ index integer")
            b = bytes[p]; p += 1
            value |= UInt64(b & 0x7f) << (7k)
            if b < 0x80
                k > 0 && b == 0 && error("noncanonical XZ index integer")
                return value,p
            end
        end
        error("oversized XZ index integer")
    end
    count,p = integer(start+1)
    count <= (limit-p) ÷ 2 || error("invalid XZ index record count")
    output = Int128(0); padded = Int128(0)
    for _ in 1:count
        unpadded,p = integer(p); decoded,p = integer(p)
        unpadded > 0 || error("invalid XZ indexed block length")
        output += decoded; padded += (Int128(unpadded)+3) & ~Int128(3)
        output <= declared || error("XZ index exceeds declared decoded length")
    end
    output == declared || error("XZ index decoded length mismatch")
    padded == start-q-12 || error("XZ indexed block sizes disagree with stream")
    0 <= limit-p <= 3 && all(iszero,view(bytes,p:limit-1)) || error("invalid XZ index padding")
    return nothing
end
