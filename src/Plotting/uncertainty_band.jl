"""
    uncertainty_band(templates; nuisances=infer_nuisances(templates), stat=true,
                     syst=true, symmetrize=nothing, label=nothing) -> UncertaintyBand

Prefit uncertainty band of the summed prediction of `templates` (vector of
[`SampleTemplates`](@ref), e.g. the output of [`group_templates`](@ref)).
Per bin, each nuisance gives `(high, low)` via [`nuisance_shifts`](@ref);
nuisances are combined in quadrature (independent sources) and the MC
statistical uncertainty `sqrt(Σ sumw2)` is added in quadrature when
`stat=true`. `symmetrize` (if not `nothing`) overrides the mode of every
nuisance. The default `label` names what is included.
"""
function uncertainty_band(templates::AbstractVector{SampleTemplates};
                          nuisances::AbstractVector{Nuisance}=infer_nuisances(templates),
                          stat::Bool=true, syst::Bool=true,
                          symmetrize::Union{Nothing,Symbol}=nothing,
                          label::Union{Nothing,AbstractString}=nothing)
    isempty(templates) && throw(ArgumentError("no templates"))
    edges = first(templates).nominal.edges
    all(t -> t.nominal.edges == edges, templates) || throw(ArgumentError("templates have different binning"))
    nb = length(edges) - 1
    prediction = reduce(+, (t.nominal.sumw for t in templates))
    statunc = stat ? sqrt.(reduce(+, (t.nominal.sumw2 for t in templates))) : zeros(nb)
    used = syst ? (symmetrize === nothing ? collect(nuisances) : [with_symmetrize(n, symmetrize) for n in nuisances]) :
           Nuisance[]
    shifts = [nuisance_shifts(templates, n) for n in used]
    shi = sqrt.(reduce(+, (s[1] .^ 2 for s in shifts); init=zeros(nb)))
    slo = sqrt.(reduce(+, (s[2] .^ 2 for s in shifts); init=zeros(nb)))
    text = label !== nothing ? label :
           stat && syst && !isempty(used) ? "Stat. #oplus syst. unc." :
           isempty(used) ? "Stat. unc." : "Syst. unc."
    return UncertaintyBand(edges, prediction, statunc, shi, slo, hypot.(statunc, shi), hypot.(statunc, slo),
                           [n.name for n in used], shifts, text)
end
