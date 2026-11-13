"""
    UncertaintyBand

Per-bin total prediction and its uncertainty, as drawn around the stacked
prediction and as `1 ± unc / prediction` in the ratio panel. Fields:

- `edges`, `prediction` (unclamped sum of the nominal contributions),
- `stat`: MC statistical uncertainty `sqrt(Σ sumw2)` (zero when not included),
- `syst_high`, `syst_low`: quadrature sum over nuisances,
- `high`, `low`: total upper and lower uncertainty (`stat ⊕ syst`),
- `nuisances`, `shifts`: per-nuisance `(high, low)` vectors in the same order,
- `label`: legend text (ROOT TLatex).

Built by [`uncertainty_band`](@ref) (prefit) or [`postfit_band`](@ref).
"""
struct UncertaintyBand
    edges::Vector{Float64}
    prediction::Vector{Float64}
    stat::Vector{Float64}
    syst_high::Vector{Float64}
    syst_low::Vector{Float64}
    high::Vector{Float64}
    low::Vector{Float64}
    nuisances::Vector{String}
    shifts::Vector{Tuple{Vector{Float64},Vector{Float64}}}
    label::String

    function UncertaintyBand(edges, prediction, stat, syst_high, syst_low, high, low,
                             nuisances, shifts, label)
        n = length(prediction)
        length(edges) == n + 1 && all(v -> length(v) == n, (stat, syst_high, syst_low, high, low)) ||
            throw(ArgumentError("band vectors must have one value per bin"))
        all(v -> all(x -> isfinite(x) && x >= 0, v), (stat, syst_high, syst_low, high, low)) ||
            throw(ArgumentError("band uncertainties must be finite and non-negative"))
        length(nuisances) == length(shifts) || throw(ArgumentError("one shift pair per nuisance is needed"))
        return new(Float64.(edges), Float64.(prediction), Float64.(stat), Float64.(syst_high),
                   Float64.(syst_low), Float64.(high), Float64.(low), String.(nuisances),
                   collect(shifts), String(label))
    end
end
