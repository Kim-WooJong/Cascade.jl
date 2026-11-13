"""
    load_correctionset(path) -> CorrectionSet

Load a correctionlib schema-v2 file. Gzip-compressed files (`.json.gz`) are
detected from their magic bytes. Throws [`CorrectionError`](@ref) on invalid
content.
"""
function load_correctionset(path::AbstractString)
    isfile(path) || throw_correction_error("Failed to open file: $path")
    bytes = read(path)
    if length(bytes) >= 2 && bytes[1] == 0x1f && bytes[2] == 0x8b
        bytes = transcode(GzipDecompressor, bytes)
    end
    return parse_correctionset(bytes)
end

"""
    parse_correctionset(json::Union{AbstractString,AbstractVector{UInt8}}) -> CorrectionSet

Build a [`CorrectionSet`](@ref) from JSON text. NaN and infinities are
accepted as numbers and numbers are converted exactly as correctionlib's
RapidJSON parser does (see `read_json`).
"""
function parse_correctionset(data::Union{AbstractString,AbstractVector{UInt8}})
    json = read_json(data)
    isjsonobject(json) || throw_correction_error("Expected CorrectionSet object")
    return CorrectionSet(json)
end
