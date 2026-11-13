"""
    nuisance_shifts(templates, nuisance::Nuisance; integrate=false) -> (high, low)

Non-negative upper and lower uncertainties of the summed prediction of
`templates` (a vector of [`SampleTemplates`](@ref) with common binning, or one
`SampleTemplates`) due to `nuisance`, following its rule and symmetrization
(see [`Nuisance`](@ref)). Per bin by default; `integrate=true` applies the rule
to the shifts of the integrated yield (fully correlated across bins) and returns
one-element vectors.
"""
function nuisance_shifts(templates::AbstractVector{SampleTemplates}, n::Nuisance; integrate::Bool=false)
    isempty(templates) && throw(ArgumentError("no templates"))
    edges = first(templates).nominal.edges
    all(t -> t.nominal.edges == edges, templates) || throw(ArgumentError("templates have different binning"))
    deltas = [variation_delta(templates, v, integrate) for v in n.variations]
    if n.rule == :updown
        du = deltas[1]
        dd = length(deltas) == 2 ? deltas[2] : -du
        if n.symmetrize == :half_difference
            s = abs.(du .- dd) ./ 2
            return (s, copy(s))
        end
        hi = max.(0.0, du, dd)
        lo = max.(0.0, -du, -dd)
    elseif n.rule == :envelope
        hi = max.(0.0, reduce((a, b) -> max.(a, b), deltas))
        lo = max.(0.0, -reduce((a, b) -> min.(a, b), deltas))
    else
        hi = sqrt.(reduce(+, (max.(d, 0.0) .^ 2 for d in deltas)))
        lo = sqrt.(reduce(+, (min.(d, 0.0) .^ 2 for d in deltas)))
    end
    return symmetrized(hi, lo, n.symmetrize)
end

nuisance_shifts(t::SampleTemplates, n::Nuisance; integrate::Bool=false) = nuisance_shifts([t], n; integrate)

"""Summed per-bin (or integrated) shift of variation `v` over `templates`."""
function variation_delta(templates, v::String, integrate::Bool)
    d = zeros(length(first(templates).nominal.sumw))
    for t in templates
        h = get(t.variations, v, nothing)
        h === nothing || (d .+= h.sumw .- t.nominal.sumw)
    end
    return integrate ? [sum(d)] : d
end

function symmetrized(hi, lo, mode::Symbol)
    mode == :none && return (hi, lo)
    s = mode == :max ? max.(hi, lo) : (hi .+ lo) ./ 2
    return (s, copy(s))
end
