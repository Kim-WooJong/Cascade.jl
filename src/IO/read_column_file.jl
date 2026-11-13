"""
    read_column_file(path; names = nothing) -> (cols::Dict{String,Any}, meta::Dict{String,Any}, order::Vector{String})

Read a Cascade column file written by `write_column_file`. If `names` is given
only those columns are materialised.
"""
function read_column_file(path::AbstractString; names = nothing)
    open(path, "r") do io
        read(io, 8) == COLFILE_MAGIC || throw(ArgumentError("$path is not a Cascade column file"))
        hlen = Int(ltoh(read(io, UInt64)))
        header = JSON3.read(read(io, hlen))
        meta = _plain(header[:meta])
        cols = Dict{String,Any}()
        order = String[]
        for d in header[:columns]
            name = String(d[:name])
            T = COLFILE_TYPES[String(d[:eltype])]
            want = names === nothing || name in names
            push!(order, name)
            if d[:jagged]
                n = Int(d[:length]); m = Int(d[:content_length])
                if want
                    offs = read!(io, Vector{Int64}(undef, n + 1))
                    content = read!(io, Vector{T}(undef, m))
                    cols[name] = Jagged{T}(content, Vector{Int}(offs))
                else
                    skip(io, 8 * (n + 1) + sizeof(T) * m)
                end
            else
                n = Int(d[:length])
                want ? (cols[name] = read!(io, Vector{T}(undef, n))) : skip(io, sizeof(T) * n)
            end
        end
        return cols, meta, order
    end
end

_plain(x::JSON3.Object) = Dict{String,Any}(String(k) => _plain(v) for (k, v) in pairs(x))
_plain(x::JSON3.Array) = Any[_plain(v) for v in x]
_plain(x) = x
