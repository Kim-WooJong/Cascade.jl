"""
    LazyEventSource(format, path; options = Dict())

Invocation-local owner of a source opened on the first source operation. It
forwards each read, including its needed mask, without caching column values
or validation results. Borrowers must not close this owner; its enclosing
scope calls close_source once, including on failure. A closed owner cannot
be reopened.
"""
mutable struct LazyEventSource <: AbstractEventSource
    format::String
    path::String
    options::Dict{String,Any}
    source::Any
    closed::Bool
end
LazyEventSource(format::AbstractString, path::AbstractString; options::AbstractDict = Dict()) =
    LazyEventSource(String(format), String(path), Dict{String,Any}(options), nothing, false)

function _owned_source(s::LazyEventSource)
    s.closed && throw(ArgumentError("source owner is closed: $(s.path)"))
    s.source === nothing && (s.source = open_source(s.format, s.path; options = s.options))
    return s.source
end
nevents(s::LazyEventSource) = nevents(_owned_source(s))
column_names(s::LazyEventSource) = column_names(_owned_source(s))
read_columns(s::LazyEventSource, names::AbstractVector{<:AbstractString}; needed = nothing) =
    read_columns(_owned_source(s), names; needed)
gen_weight_sum(s::LazyEventSource) = gen_weight_sum(_owned_source(s))
normalization_metadata(s::LazyEventSource) = normalization_metadata(_owned_source(s))
source_signature(s::LazyEventSource) = source_signature(_owned_source(s))
function close_source(s::LazyEventSource)
    s.closed && return nothing
    s.closed = true
    source = s.source
    s.source = nothing
    source === nothing || close_source(source)
    return nothing
end
