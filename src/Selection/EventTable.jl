"""
    EventTable(columns, order, meta)

Kept events of one chunk: `entry` (1-based event index in the source),
`stage` (number of sequential cuts passed), `weight` (base nominal weight) and
one Float64 column per compiled output (`h:<hist>:<k>` histogram values, NaN =
not filled; `w:<name>Up/Down` weight-variation factors; `v:<var>` extra
variables). `meta` records cut names, region stages and the output layout.
"""
struct EventTable
    columns::Dict{String,Vector}
    order::Vector{String}
    meta::Dict{String,Any}
end

"""
    nrows(t::EventTable) -> Int

Number of kept events.
"""
nrows(t::EventTable) = isempty(t.order) ? 0 : length(t.columns[first(t.order)])

Base.getindex(t::EventTable, name::AbstractString) = t.columns[name]
Base.haskey(t::EventTable, name::AbstractString) = haskey(t.columns, name)
