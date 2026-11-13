"""
    NormSysTerm

Multiplicative normalisation systematic acting on one sample
(`hi`/`lo` are relative factors at alpha = +1/-1).
`coeffs` holds the polynomial coefficients used by interpolation code 4.
"""
struct NormSysTerm
    par::Int
    hi::Float64
    lo::Float64
    code::Symbol
    coeffs::NTuple{6,Float64}
end

"""
    HistoSysTerm

Additive shape systematic acting on one sample; `up`/`dn` are the absolute
variated templates at alpha = +1/-1.
"""
struct HistoSysTerm
    par::Int
    up::Vector{Float64}
    dn::Vector{Float64}
    code::Symbol
end

"""
    SampleTerm

One sample in one channel: nominal template, global bin range and the
modifiers acting on it. `factors` are scalar multiplicative parameters
(normfactor, lumi); `binfactors` map each local bin to a per-bin
multiplicative parameter (shapesys, staterror, shapefactor; 0 = none).
"""
struct SampleTerm
    name::String
    channel::Int
    bins::UnitRange{Int}
    nominal::Vector{Float64}
    factors::Vector{Int}
    normsys::Vector{NormSysTerm}
    histosys::Vector{HistoSysTerm}
    binfactors::Vector{Vector{Int}}
end

"""
    HistModel

Compiled binned HistFactory-like model (channels x samples x bins).
Build it from a pyhf-style workspace with
`HistModel(spec; measurement, poi, normsys_code, histosys_code)`.

Channels are ordered alphabetically and parameters are ordered by modifier
name (then bin), following pyhf, so results can be compared by name.
`observations` holds the observed main-measurement counts (empty if the
spec has none), concatenated over the ordered channels.
"""
struct HistModel
    channels::Vector{String}
    channel_bins::Vector{UnitRange{Int}}
    samples::Vector{SampleTerm}
    parameters::Vector{ParameterInfo}
    index::Dict{String,Int}
    poi::Int
    observations::Vector{Float64}
end
