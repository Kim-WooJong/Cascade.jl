const NUISANCE_RULES = (:updown, :envelope, :quadrature)
const SYMMETRIZE_MODES = (:none, :max, :average, :half_difference)

"""
    Nuisance(name; up=name * "Up", down=name * "Down", symmetrize=:none)
    Nuisance(name, variations; rule=:envelope, symmetrize=:none)

One systematic source of the prediction uncertainty band. For each listed
variation `v` the shift `δ_v = Σ_samples (h_v - h_nominal)` is taken per bin
(fully correlated between samples; a sample without `v` contributes 0). The
non-negative upper and lower uncertainties then follow `rule`:

- `:updown` (first form): one up and one down variation. Upper
  `= max(0, δ_up, δ_down)`, lower `= max(0, -δ_up, -δ_down)`, so two shifts on
  the same side give a one-sided uncertainty. `down=nothing` declares a
  one-sided variation, mirrored (`δ_down = -δ_up`).
- `:envelope`: several alternatives (e.g. QCD scale choices). Upper
  `= max(0, max_v δ_v)`, lower `= max(0, -min_v δ_v)`.
- `:quadrature`: several independent shifts (e.g. Hessian PDF eigenvectors).
  Upper `= sqrt(Σ_v max(δ_v, 0)²)`, lower `= sqrt(Σ_v min(δ_v, 0)²)`.

`symmetrize` then makes both sides equal: `:max` (larger side), `:average`
(mean of the two sides) or, for `:updown` only, `:half_difference`
(`|δ_up - δ_down| / 2`); `:none` keeps them as computed.
"""
struct Nuisance
    name::String
    rule::Symbol
    variations::Vector{String}
    symmetrize::Symbol

    function Nuisance(name::AbstractString, rule::Symbol, variations::AbstractVector, symmetrize::Symbol)
        isempty(name) && throw(ArgumentError("empty nuisance name"))
        rule in NUISANCE_RULES || throw(ArgumentError("rule must be one of $(NUISANCE_RULES)"))
        symmetrize in SYMMETRIZE_MODES || throw(ArgumentError("symmetrize must be one of $(SYMMETRIZE_MODES)"))
        vs = String.(variations)
        isempty(vs) && throw(ArgumentError("nuisance $name has no variation"))
        allunique(vs) || throw(ArgumentError("nuisance $name lists a variation twice"))
        rule == :updown && length(vs) > 2 && throw(ArgumentError(":updown takes one up and at most one down variation"))
        symmetrize == :half_difference && rule != :updown &&
            throw(ArgumentError(":half_difference applies to :updown nuisances only"))
        return new(String(name), rule, vs, symmetrize)
    end
end

Nuisance(name::AbstractString; up::AbstractString=name * "Up",
         down::Union{Nothing,AbstractString}=name * "Down", symmetrize::Symbol=:none) =
    Nuisance(name, :updown, down === nothing ? [up] : [up, down], symmetrize)

Nuisance(name::AbstractString, variations::AbstractVector; rule::Symbol=:envelope, symmetrize::Symbol=:none) =
    Nuisance(name, rule, variations, symmetrize)

"""Copy of `n` with another symmetrization mode."""
with_symmetrize(n::Nuisance, mode::Symbol) = Nuisance(n.name, n.rule, n.variations, mode)
