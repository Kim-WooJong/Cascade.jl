"""Bounded schema2 physical payload; no independent normalization population."""
struct ReducedShardSource <: AbstractEventSource
    path::String
    file::UnROOT.ROOTFile
    tree::Any
    meta::Dict{String,Any}
end
function ReducedShardSource(path::AbstractString; metadata = nothing)
    meta = metadata === nothing ? read_reduced_shard(path) : metadata; f = UnROOT.ROOTFile(path)
    try
        f["Events"] isa UnROOT.RNTuple || error("physical Events is not RNTuple")
        tree = UnROOT.LazyTree(f, "Events")
        length(tree) == meta["nevents"] || error("shard count mismatch")
        Set(String.(propertynames(tree))) == Set(d["name"] for d in meta["columns"]) || error("shard schema mismatch")
        for descriptor in meta["columns"]
            values = getproperty(tree, Symbol(descriptor["name"]))
            T = descriptor["jagged"] ? eltype(eltype(values)) : eltype(values)
            string(T) == descriptor["eltype"] || error("physical primitive schema mismatch")
        end
        entries = collect(tree.cascade_source_entry)
        eltype(entries) == Int64 && issorted(entries) && all(i -> entries[i] < entries[i+1], 1:max(0,length(entries)-1)) &&
            all(e -> meta["source_begin"] <= e <= meta["source_end"], entries) || error("invalid shard source-entry mapping")
        return ReducedShardSource(String(path), f, tree, meta)
    catch
        close(f); rethrow()
    end
end
nevents(s::ReducedShardSource) = Int(s.meta["nevents"])
column_names(s::ReducedShardSource) = String[d["name"] for d in s.meta["columns"]]
read_columns(s::ReducedShardSource, names::AbstractVector{<:AbstractString}; needed = nothing) =
    read_columns(ReducedRNTupleSource(s.path, s.file, s.tree, s.meta), names; needed)
gen_weight_sum(s::ReducedShardSource) = error("physical shard has no independent denominator; require the complete logical-source ledger")
normalization_metadata(s::ReducedShardSource) = error("physical shard normalization requires complete logical-source scope")
source_population(s::ReducedShardSource) = error("physical shard ownership requires its complete group")
source_signature(s::ReducedShardSource) = merge(file_signature(s.path), Dict{String,Any}("format" => "reduced_rntuple_group"))
close_source(s::ReducedShardSource) = (close(s.file); nothing)
register_source_format!("reduced_rntuple_shard", ReducedShardSource)
