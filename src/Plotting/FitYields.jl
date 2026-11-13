"""
    FitYields(edges, yields, errors; errors_low=errors, yield_errors=Dict{String,Float64}(),
              total_error=NaN, label="Postfit unc.")

Minimal interface between a fit result and the postfit plots/tables.

- `edges`: bin edges of the fitted distribution.
- `yields`: process name `=>` postfit yield per bin (process names may be the
  sample names of a [`StackConfig`](@ref) or directly its group labels).
- `errors`, `errors_low`: total postfit uncertainty of the summed prediction per
  bin (upper, lower), computed by the fit from the full covariance including
  MC-statistical nuisances. Plotting does not recombine per-process errors.
- `yield_errors`: optional postfit uncertainty of the integrated yield per
  process or group label (used by [`yield_table`](@ref); missing entries are
  shown as n/a).
- `total_error`: postfit uncertainty of the integrated total prediction (`NaN`
  when unknown).
- `label`: legend text of the band.
"""
struct FitYields
    edges::Vector{Float64}
    yields::Dict{String,Vector{Float64}}
    errors_high::Vector{Float64}
    errors_low::Vector{Float64}
    yield_errors::Dict{String,Float64}
    total_error::Float64
    label::String

    function FitYields(edges::AbstractVector{<:Real}, yields::AbstractDict, errors::AbstractVector{<:Real};
                       errors_low::AbstractVector{<:Real}=errors,
                       yield_errors::AbstractDict=Dict{String,Float64}(),
                       total_error::Real=NaN, label::AbstractString="Postfit unc.")
        e = Float64.(edges)
        n = length(e) - 1
        n >= 1 && all(diff(e) .> 0) || throw(ArgumentError("invalid bin edges"))
        isempty(yields) && throw(ArgumentError("no postfit yields"))
        ys = Dict{String,Vector{Float64}}()
        for (k, v) in yields
            length(v) == n && all(isfinite, v) || throw(ArgumentError("postfit yields of $k need $n finite values"))
            ys[String(k)] = Float64.(v)
        end
        hi, lo = Float64.(errors), Float64.(errors_low)
        length(hi) == n == length(lo) && all(x -> isfinite(x) && x >= 0, [hi; lo]) ||
            throw(ArgumentError("postfit errors need $n finite non-negative values"))
        ye = Dict{String,Float64}(String(k) => Float64(v) for (k, v) in yield_errors)
        return new(e, ys, hi, lo, ye, Float64(total_error), String(label))
    end
end
