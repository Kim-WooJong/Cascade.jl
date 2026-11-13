"""
    NormSysSpec(name, hi, lo, samples, placeholder)

Log-normal normalisation uncertainty (pyhf `normsys`): factors `hi`/`lo` at
`alpha = ±1` on the fit samples `samples` (empty = every simulated fit
sample). `placeholder = true` marks an assumed value that is not a validated
uncertainty; it is carried into the fit result.
"""
struct NormSysSpec
    name::String
    hi::Float64
    lo::Float64
    samples::Vector{String}
    placeholder::Bool
end
