"""Standalone verified ROOT RNTuple bundle source (format reduced_rntuple).

Reads only published bundle bytes. Original paths are never reopened. Local
row indices remain correction-reader indices; cascade_source_entry is separate.
"""
struct ReducedRNTupleSource <: AbstractEventSource
    path::String
    file::UnROOT.ROOTFile
    tree::Any
    meta::Dict{String,Any}
end

function ReducedRNTupleSource(path::AbstractString)
    meta = read_reduced_metadata(path)
    f = UnROOT.ROOTFile(path)
    try
        f["Events"] isa UnROOT.RNTuple || error("reduced Events is not a ROOT RNTuple")
        t = UnROOT.LazyTree(f, "Events")
        length(t) == meta["retained_nevents"] || error("reduced event count mismatch")
        Set(String.(propertynames(t))) == Set(d["name"] for d in meta["columns"]) || error("reduced schema names mismatch")
        length(unique(d["name"] for d in meta["columns"])) == length(meta["columns"]) || error("duplicate reduced schema column")
        0 <= meta["payload_bytes"] <= 64_000_000 || error("invalid reduced payload limit")
        mapping = collect(getproperty(t, :cascade_source_entry))
        eltype(mapping) == Int64 && issorted(mapping) && length(unique(mapping)) == length(mapping) &&
            all(e -> 1 <= e <= meta["original_nevents"], mapping) || error("invalid original source-entry mapping")
        return ReducedRNTupleSource(String(path), f, t, meta)
    catch
        close(f)
        rethrow()
    end
end

nevents(s::ReducedRNTupleSource) = Int(s.meta["retained_nevents"])
column_names(s::ReducedRNTupleSource) = String[d["name"] for d in s.meta["columns"]]
gen_weight_sum(s::ReducedRNTupleSource) = s.meta["kind"] == "mc" ? Float64(s.meta["normalization"]["value"]) : 0.0
normalization_metadata(s::ReducedRNTupleSource) = deepcopy(s.meta["normalization"])
source_population(s::ReducedRNTupleSource) = deepcopy(s.meta["population"])
source_signature(s::ReducedRNTupleSource) = merge(file_signature(s.path), Dict{String,Any}("format" => "reduced_rntuple"))
close_source(s::ReducedRNTupleSource) = (close(s.file); nothing)

function read_columns(s::ReducedRNTupleSource, names::AbstractVector{<:AbstractString}; needed = nothing)
    needed === nothing || length(needed) == nevents(s) || error("reduced needed length mismatch")
    out = Dict{String,Any}()
    for name in unique(names)
        i = findfirst(d -> d["name"] == name, s.meta["columns"])
        i === nothing && error("missing reduced branch $name")
        d = s.meta["columns"][i]
        T = COLFILE_TYPES[d["eltype"]]
        values = getproperty(s.tree, Symbol(name))
        if d["jagged"]
            eltype(eltype(values)) == T || error("reduced branch element type mismatch: $name")
            out[String(name)] = Jagged([collect(T, v) for v in values])
        else
            eltype(values) == T || error("reduced branch type mismatch: $name")
            out[String(name)] = collect(T, values)
        end
    end
    return out
end

register_source_format!("reduced_rntuple", ReducedRNTupleSource)
