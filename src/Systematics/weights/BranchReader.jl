"""
    BranchReader(format, path, entries)

Lazy reader of event-level branches of the source file of a chunk, restricted
to the rows `entries` (1-based event indices, the `entry` column of the event
table). `r(name)` returns the branch values of those rows as
`Vector{Float64}` (cached); the file is opened on first use. Call
`close(r)` when done. Vector-member access is the separate
`vector_members(r, spec)` API with explicit normalization/layout contracts.
"""
mutable struct BranchReader
    format::String
    path::String
    entries::Vector{Int}
    source::Any
    options::Dict{String,Any}
    cache::Dict{String,Vector{Float64}}
    vectors::Dict{String,Jagged}
    owns_source::Bool
end

BranchReader(format::AbstractString, path::AbstractString, entries::AbstractVector{<:Integer}; options::AbstractDict = Dict(), source = nothing) =
    BranchReader(String(format), String(path), Vector{Int}(entries), source, Dict{String,Any}(options), Dict{String,Vector{Float64}}(), Dict{String,Jagged}(), source === nothing)

BranchReader(format::String, path::String, entries::Vector{Int}, source, options::Dict{String,Any}, cache::Dict{String,Vector{Float64}}) =
    BranchReader(format, path, entries, source, options, cache, Dict{String,Jagged}(), true)

BranchReader(format::String, path::String, entries::Vector{Int}, source, options::Dict{String,Any},
             cache::Dict{String,Vector{Float64}}, vectors::Dict{String,Jagged}) =
    BranchReader(format, path, entries, source, options, cache, vectors, true)

function (r::BranchReader)(name::AbstractString)
    haskey(r.cache, name) && return r.cache[name]
    isempty(r.entries) && return (r.cache[String(name)] = Float64[])
    if r.source === nothing
        r.source = open_source(r.format, r.path; options = r.options)
    end
    src = r.source
    n = nevents(src)
    String(name) in column_names(src) ||
        throw(ArgumentError("branch '$name' not found in $(r.path)"))
    needed = fill(false, n)
    for e in r.entries
        1 <= e <= n || throw(ArgumentError("entry $e out of range 1:$n in $(r.path)"))
        needed[e] = true
    end
    col = read_columns(src, [String(name)]; needed)[String(name)]
    col isa AbstractVector && !(col isa Jagged) ||
        throw(ArgumentError("branch '$name' is not an event-level scalar; use [[corrections.object_sf]]"))
    v = Float64[Float64(col[e]) for e in r.entries]
    r.cache[String(name)] = v
    return v
end

function Base.close(r::BranchReader)
    r.source === nothing || !r.owns_source || close_source(r.source)
    r.source = nothing
    return nothing
end
