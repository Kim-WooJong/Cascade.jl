const COLFILE_MAGIC = b"CASCOL01"

const COLFILE_TYPES = Dict{String,DataType}(
    "Bool" => Bool, "Int8" => Int8, "Int16" => Int16, "Int32" => Int32, "Int64" => Int64,
    "UInt8" => UInt8, "UInt16" => UInt16, "UInt32" => UInt32, "UInt64" => UInt64,
    "Float32" => Float32, "Float64" => Float64)

"""
    write_column_file(path, cols::AbstractDict; order = sort(keys), meta = Dict())

Write columns (`Vector{T}` or `Jagged{T}` of bits types) to the Cascade column
file format: magic `CASCOL01`, little-endian `UInt64` header length, JSON header
(`meta` and column descriptors), then raw column data (`Jagged`: Int64 offsets
followed by content). The file is written to a temporary name and renamed.
Values round-trip bit-exactly.
"""
function write_column_file(path::AbstractString, cols::AbstractDict;
                           order::AbstractVector = sort!(String.(collect(keys(cols)))),
                           meta::AbstractDict = Dict{String,Any}())
    descs = Any[]
    for n in order
        c = cols[n]
        T = eltype(c isa Jagged ? c.content : c)
        haskey(COLFILE_TYPES, string(T)) || throw(ArgumentError("column $n: unsupported eltype $T"))
        push!(descs, Dict("name" => String(n), "eltype" => string(T), "jagged" => c isa Jagged,
                          "length" => length(c), "content_length" => c isa Jagged ? length(c.content) : length(c)))
    end
    header = Vector{UInt8}(JSON3.write(Dict("version" => 1, "meta" => meta, "columns" => descs)))
    mkpath(dirname(abspath(path)))
    tmp = string(path, ".tmp.", getpid(), ".", objectid(cols))
    open(tmp, "w") do io
        write(io, COLFILE_MAGIC)
        write(io, htol(UInt64(length(header))))
        write(io, header)
        for n in order
            c = cols[n]
            if c isa Jagged
                # Already-exact storage is written directly (no duplicate copy);
                # any other representation is converted exactly as before.
                write(io, c.offsets isa Vector{Int64} ? c.offsets : Vector{Int64}(c.offsets))
                write(io, c.content)
            else
                write(io, c isa Vector ? c : Vector(c))  # BitVector/views/ranges still convert
            end
        end
    end
    mv(tmp, path; force = true)
    return path
end
