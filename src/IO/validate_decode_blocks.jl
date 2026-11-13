"""Validate ROOT block framing without native calls. Only checked single-stream XZ transcode is enabled.

Returns immutable numeric block descriptors, or nothing for another codec.
Structural corruption is an error, never an unsupported-codec fallback.
"""
function validate_decode_blocks(bytes, declared::Integer)
    declared >= 0 || error("negative decoded basket length")
    blocks = Tuple{Int,Int,Int}[]
    p = 1; total = Int128(0)
    while p <= length(bytes)
        length(bytes) - p + 1 >= 9 || error("truncated compression header")
        c = Int(bytes[p+3]) + (Int(bytes[p+4]) << 8) + (Int(bytes[p+5]) << 16)
        d = Int(bytes[p+6]) + (Int(bytes[p+7]) << 8) + (Int(bytes[p+8]) << 16)
        c > 0 && d > 0 && c <= length(bytes) - p - 8 || error("invalid compression block length")
        total += d
        total <= declared || error("compression blocks exceed decoded basket length")
        q = p + 9
        if bytes[p] == UInt8('X') && bytes[p+1] == UInt8('Z')
            bytes[p+2] == 0 && c >= 24 || error("invalid ROOT XZ framing")
            all(bytes[q+i-1] == v for (i,v) in enumerate((0xfd,0x37,0x7a,0x58,0x5a,0x00))) || error("invalid XZ stream header")
            validate_decode_xz_index(bytes,q,c,d)
        else
            return nothing
        end
        push!(blocks, (q, c, d))
        p += 9 + c
    end
    p == length(bytes) + 1 && total == declared || error("compression block total mismatch")
    return Tuple(blocks)
end
