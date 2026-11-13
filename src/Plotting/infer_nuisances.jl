"""
    infer_nuisances(templates; up_suffix="Up", down_suffix="Down", symmetrize=:none) -> Vector{Nuisance}

Derive `:updown` nuisances from the variation names of `templates` (a vector or
dictionary of [`SampleTemplates`](@ref)), sorted by name: `"xUp"` and `"xDown"`
form nuisance `x`; a lone `"xUp"` or `"xDown"`, or a name without either
suffix, becomes a one-sided mirrored nuisance. Use explicit [`Nuisance`](@ref)
values for envelope or quadrature groups.
"""
function infer_nuisances(templates; up_suffix::AbstractString="Up", down_suffix::AbstractString="Down",
                         symmetrize::Symbol=:none)
    list = templates isa AbstractDict ? collect(values(templates)) : collect(templates)
    names = Set{String}()
    for t in list
        union!(names, keys(t.variations))
    end
    base(v) = endswith(v, up_suffix) ? v[1:prevind(v, end, length(up_suffix))] :
              endswith(v, down_suffix) ? v[1:prevind(v, end, length(down_suffix))] : v
    out = Nuisance[]
    for b in sort!(unique(base.(collect(names))))
        isempty(b) && throw(ArgumentError("variation name without a nuisance name"))
        up, down = b * up_suffix, b * down_suffix
        hasup, hasdown = up in names, down in names
        n = hasup && hasdown ? Nuisance(b; up, down, symmetrize) :
            hasup ? Nuisance(b; up, down=nothing, symmetrize) :
            hasdown ? Nuisance(b; up=down, down=nothing, symmetrize) :
            Nuisance(b; up=b, down=nothing, symmetrize)
        push!(out, n)
    end
    return out
end
