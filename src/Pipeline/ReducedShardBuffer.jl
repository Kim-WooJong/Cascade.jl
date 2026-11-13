"""One bounded typed physical-shard buffer; never stores past windows or shards."""
mutable struct ReducedShardBuffer
    columns::Dict{String,Any}
    bytes::Int
end
function ReducedShardBuffer(schema)
    columns = Dict{String,Any}()
    for d in schema
        T = COLFILE_TYPES[d["eltype"]]
        columns[d["name"]] = d["jagged"] ? Jagged(T[], [0]) : T[]
    end
    return ReducedShardBuffer(columns, 8 * count(d -> d["jagged"], schema))
end
