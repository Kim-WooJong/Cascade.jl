"""Check fixed ROOT header metadata declarations before opening/decompressing them."""
function validate_stream_metadata(path, options)
    bytes = open(io -> read(io, min(filesize(path), 2048)), path)
    length(bytes) >= 64 && bytes[1:4] == UInt8[0x72,0x6f,0x6f,0x74] || error("invalid ROOT header")
    io = IOBuffer(bytes); preamble = UnROOT.unpack(io, UnROOT.FilePreamble)
    header = UnROOT.unpack(io, preamble.fVersion < 1_000_000 ? UnROOT.FileHeader32 : UnROOT.FileHeader64)
    0 <= header.fNbytesInfo <= options["max_metadata_bytes"] || error("ROOT streamer metadata exceeds max_metadata_bytes")
    return nothing
end
