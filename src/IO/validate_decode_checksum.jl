"""Check XZ block coverage after native checked transcode.

Checksum/stream-status validation belongs to XZ transcode. Zlib is deliberately
unsupported: an independent Adler checksum cannot establish DEFLATE termination.
"""
function validate_decode_checksum(raw, compressed, blocks)
    total = Int128(0)
    for (q,c,d) in blocks
        compressed[q-9] == UInt8('X') && compressed[q-8] == UInt8('Z') || error("unsupported detached codec")
        total += d
    end
    total == length(raw) || error("decoded XZ length mismatch")
    return nothing
end
