"""
    HistogramConfig

Histogram definition. `edges` are the bin edges (built by `parse_binning`).
Each expression in `values` is filled once per selected event (several values
fill the same histogram several times, in the given order). `when` is an event
expression gating the fill (`"true"` by default). `regions` restricts the
regions it is filled in (empty = all regions).
"""
struct HistogramConfig
    name::String
    edges::Vector{Float64}
    values::Vector{String}
    when::String
    regions::Vector{String}
    xlabel::String
end
