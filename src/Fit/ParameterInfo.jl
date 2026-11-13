"""
    ParameterInfo

Description of one scalar model parameter of a [`HistModel`](@ref).

Fields:
- `name`: unique parameter name. Scalar modifiers use the modifier name
  (`"mu"`, `"lumi"`); per-bin modifiers append a zero-based bin index
  (`"staterror_SR[0]"`), as in pyhf.
- `group`: modifier name the parameter belongs to.
- `kind`: modifier type (`:normfactor`, `:lumi`, `:normsys`, `:histosys`,
  `:shapesys`, `:staterror`, `:shapefactor`).
- `init`, `lower`, `upper`: starting value and bounds used by the fit.
- `fixed`: parameter is held constant at `init` in every fit.
- `constraint`: `:none`, `:gauss` or `:poisson`.
- `aux`: nominal auxiliary measurement (Gaussian mean, or Poisson count `tau`).
- `sigma`: pre-fit uncertainty of the parameter (Gaussian width; `1/sqrt(tau)`
  for Poisson constraints; `NaN` for unconstrained parameters).
- `tau`: Poisson constraint scale (`NaN` unless `constraint == :poisson`).
"""
struct ParameterInfo
    name::String
    group::String
    kind::Symbol
    init::Float64
    lower::Float64
    upper::Float64
    fixed::Bool
    constraint::Symbol
    aux::Float64
    sigma::Float64
    tau::Float64
end
