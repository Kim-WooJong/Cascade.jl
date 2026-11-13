"""
    PlotOptions

Resolved `[plot]` section of an analysis (see [`plot_options`](@ref)):
output `formats`, CMS label texts (`lumi`, `energy`, `extra`), the
`regions`/`variables` to draw (empty = all), `logy` variables (drawn with a
log scale in addition to the linear one), `region_labels`, group display
`labels` and `colors`, explicit stack `groups` (`nothing` = from the sample
groups), `data` samples (`nothing` = all data samples), output switches
`prefit`, `postfit`, `tables`, `cutflow`, `impacts`, `band_normsys` (add the
`[fit]` normsys to the prefit band) and `max_impacts`.
"""
struct PlotOptions
    formats::Symbol
    lumi::String
    energy::String
    extra::String
    regions::Vector{String}
    variables::Vector{String}
    logy::Vector{String}
    region_labels::Dict{String,String}
    labels::Dict{String,String}
    colors::Dict{String,String}
    groups::Union{Nothing,Vector{Any}}
    data::Union{Nothing,Vector{String}}
    prefit::Bool
    postfit::Bool
    tables::Bool
    cutflow::Bool
    impacts::Bool
    band_normsys::Bool
    max_impacts::Int
end
