"""
    AbstractEventSource

Interface for event input. A source is one chunk of events (typically one file).
Implementations must define:

- `nevents(src)::Int`
- `column_names(src)::Vector{String}`
- `read_columns(src, names; needed = nothing)::Dict{String,Any}` — each value is
  a `Vector{T}` (one value per event) or a `Jagged{T}` (a list per event).
  If `needed` (a `Bool` vector of length `nevents`) is given, values of events
  with `needed[i] == false` are unspecified (implementations may skip reading
  them, returning zeros / empty lists).
- `gen_weight_sum(src)::Float64` — sum of generator weights of all produced
  events (MC normalisation); `0.0` for data.
- `source_signature(src)::Dict{String,Any}` — provenance (path, size, mtime, ...).
- `close_source(src)` — release resources (default: no-op).

New formats register an opener with `register_source_format!`.
"""
abstract type AbstractEventSource end

"""
    nevents(src::AbstractEventSource) -> Int

Number of events in the source.
"""
function nevents end

"""
    column_names(src::AbstractEventSource) -> Vector{String}

Names of the columns (branches) available in the source.
"""
function column_names end

"""
    read_columns(src::AbstractEventSource, names; needed = nothing) -> Dict{String,Any}

Read the named columns for all events of the source. See `AbstractEventSource`.
"""
function read_columns end

"""
    gen_weight_sum(src::AbstractEventSource) -> Float64

Sum of generator weights before any selection (MC normalisation denominator).
"""
function gen_weight_sum end

"""
    source_signature(src::AbstractEventSource) -> Dict{String,Any}

Provenance record of the source, used for artifact hashing.
"""
function source_signature end

"""
    close_source(src::AbstractEventSource)

Release resources held by the source.
"""
close_source(::AbstractEventSource) = nothing
