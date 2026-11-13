"""
    add_norm_variations(templates, name, hi, lo, samples) -> Dict{String,SampleTemplates}

Copy of `templates` where every sample in `samples` gets the normalisation
variations `"<name>Up" = hi × nominal` and `"<name>Down" = lo × nominal`
(e.g. the luminosity and cross-section uncertainties of the fit configuration,
so the prefit band shows them). Existing variations of that name are kept.
"""
function add_norm_variations(templates::AbstractDict{<:AbstractString,SampleTemplates}, name::AbstractString,
                             hi::Real, lo::Real, samples)
    out = Dict{String,SampleTemplates}()
    for (k, t) in templates
        if k in samples && !haskey(t.variations, name * "Up") && !haskey(t.variations, name * "Down")
            vs = copy(t.variations)
            vs[name * "Up"] = hist_scale(t.nominal, hi)
            vs[name * "Down"] = hist_scale(t.nominal, lo)
            out[k] = SampleTemplates(t.name, t.nominal, vs)
        else
            out[k] = t
        end
    end
    return out
end
