"""Borrowed, window-local source with a cache owned by one export iteration.

The original remains open and is never closed by a borrowed correction reader.
No needed-mask placeholders are cached. Column files are an explicitly eager
compatibility source; only NanoAOD takes the genuine bounded basket path.
"""
mutable struct EventWindowSource <: AbstractEventSource
    path::String
    source::AbstractEventSource
    range::UnitRange{Int}
    options::Dict{String,Any}
    cache::Dict{String,Any}
    metrics::Dict{String,Int}
end
EventWindowSource(source, range, options) = EventWindowSource(source.path, source, range,
    options, Dict{String,Any}(), Dict("basket_requests" => 0, "compressed_bytes" => 0,
        "peak_decoded_basket_bytes" => 0, "live_window_bytes" => 0))
nevents(s::EventWindowSource) = length(s.range)
column_names(s::EventWindowSource) = column_names(s.source)
function read_columns(s::EventWindowSource, names::AbstractVector{<:AbstractString}; needed = nothing)
    needed === nothing || length(needed) == nevents(s) || error("window mask length mismatch")
    out = Dict{String,Any}()
    for name in unique(names)
        out[String(name)] = get!(s.cache, String(name)) do
            value = if s.source isa NanoAODSource
                c, m = read_nanoaod_window(s.source.file, s.source.tree, name, s.range;
                    max_basket_bytes = s.options["max_basket_bytes"], max_window_bytes = s.options["max_window_bytes"] - s.metrics["live_window_bytes"])
                s.metrics["basket_requests"] += m["basket_requests"]
                s.metrics["compressed_bytes"] += m["compressed_bytes"]
                s.metrics["peak_decoded_basket_bytes"] = max(s.metrics["peak_decoded_basket_bytes"], m["peak_decoded_basket_bytes"])
                c
            elseif s.source isa ColumnFileSource
                c = s.source.cols[name]
                c isa Jagged ? Jagged(Vector{eltype(c.content)}[collect(c[i]) for i in s.range]) : c[s.range]
            else
                error("source has no bounded window capability")
            end
            bytes = Base.summarysize(value)
            s.metrics["live_window_bytes"] + bytes <= s.options["max_window_bytes"] || error("window branch cache exceeds max_window_bytes")
            s.metrics["live_window_bytes"] += bytes
            value
        end
    end
    return out
end
close_source(s::EventWindowSource) = nothing
