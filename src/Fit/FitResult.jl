"""
    FitResult

Result of [`fit`](@ref). All vectors are indexed like `model.parameters`.

Fields:
- `parameters`: best-fit values (fixed parameters at their fixed value).
- `uncertainties`: `sqrt.(diag(covariance))` (0 for fixed parameters).
- `covariance`: inverse Hessian of the NLL over floating parameters
  (rows/columns of fixed parameters are zero; all-zero if `hesse=false`).
- `names`: parameter names.
- `floating`: `true` for parameters that were free in this fit.
- `nll`: NLL at the minimum; `edm`, `iterations`, `converged`: minimizer status.
"""
struct FitResult
    parameters::Vector{Float64}
    uncertainties::Vector{Float64}
    covariance::Matrix{Float64}
    names::Vector{String}
    floating::Vector{Bool}
    nll::Float64
    edm::Float64
    iterations::Int
    converged::Bool
end
