"""Schema2 logical-source descriptor; Events must be processed as bounded shards."""
struct ReducedGroupSource <: AbstractEventSource
    path::String
    meta::Dict{String,Any}
end
ReducedGroupSource(path::AbstractString) = endswith(path, ".root") ? ReducedShardSource(path) : ReducedGroupSource(String(path), read_reduced_group(path))
nevents(s::ReducedGroupSource) = Int(s.meta["retained_nevents"])
column_names(s::ReducedGroupSource) = String[d["name"] for d in s.meta["columns"]]
read_columns(s::ReducedGroupSource, names::AbstractVector{<:AbstractString}; needed = nothing) = error("logical source cannot concatenate Events; enumerate its verified physical shards")
gen_weight_sum(s::ReducedGroupSource) = s.meta["kind"] == "mc" ? Float64(s.meta["normalization"]["value"]) : 0.0
normalization_metadata(s::ReducedGroupSource) = deepcopy(s.meta["normalization"])
source_population(s::ReducedGroupSource) = deepcopy(s.meta["population"])
source_signature(s::ReducedGroupSource) = merge(file_signature(s.path), Dict{String,Any}("format" => "reduced_rntuple_group"))
register_source_format!("reduced_rntuple_group", ReducedGroupSource)
