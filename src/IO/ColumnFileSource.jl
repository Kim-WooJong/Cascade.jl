"""
    ColumnFileSource(path)

Event source reading a Cascade column file (format `"cols"`). Column names are
used verbatim (NanoAOD-style names such as `Electron_pt` work unchanged), so
synthetic or pre-skimmed events can be fed to the same analysis definition.
`gen_weight_sum` uses `meta["gen_weight_sum"]` if present, else the sequential
sum of the `genWeight` column, else 0.0.
"""
struct ColumnFileSource <: AbstractEventSource
    path::String
    cols::Dict{String,Any}
    meta::Dict{String,Any}
    order::Vector{String}
    gen_weight::String
end

function ColumnFileSource(path::AbstractString; gen_weight::AbstractString = "genWeight")
    cols, meta, order = read_column_file(path)
    return ColumnFileSource(String(path), cols, meta, order, String(gen_weight))
end

nevents(s::ColumnFileSource) = isempty(s.order) ? Int(get(s.meta, "nevents", 0)) : length(s.cols[first(s.order)])

column_names(s::ColumnFileSource) = copy(s.order)

function read_columns(s::ColumnFileSource, names::AbstractVector{<:AbstractString}; needed = nothing)
    out = Dict{String,Any}()
    for n in names
        haskey(s.cols, n) || throw(KeyError("column $n not in $(s.path)"))
        out[String(n)] = s.cols[n]
    end
    return out
end

function gen_weight_sum(s::ColumnFileSource)
    haskey(s.meta, "gen_weight_sum") && return Float64(s.meta["gen_weight_sum"])
    haskey(s.cols, s.gen_weight) || return 0.0
    acc = 0.0
    for w in s.cols[s.gen_weight]
        acc += Float64(w)
    end
    return acc
end

source_signature(s::ColumnFileSource) = merge(file_signature(s.path), Dict{String,Any}("format" => "cols"))

register_source_format!("cols", ColumnFileSource)
