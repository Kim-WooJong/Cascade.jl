"""
    collect_templates(entries; nominal="nominal") -> Dict{String,SampleTemplates}

Build per-sample [`SampleTemplates`](@ref) from histograms keyed by
`(sample, variation)`. `entries` is a dictionary (or any iterable of pairs)
`(sample, variation) => hist`, where `hist` is one of

- a tuple `(edges, sumw, sumw2)` of plain arrays,
- a named tuple with fields `edges, sumw, sumw2` (optional `underflow, overflow`
  pairs, folded into the first / last bin),
- a [`BinnedHist`](@ref) (used as is), or a ROOTPlots `Hist1D` (flow folded).

Every sample needs a histogram named `nominal`; all other variation names are
kept verbatim. Duplicate keys and inconsistent binning are errors.
"""
function collect_templates(entries; nominal::AbstractString="nominal")
    bysample = Dict{String,Dict{String,BinnedHist}}()
    for ((sample, variation), value) in entries
        d = get!(() -> Dict{String,BinnedHist}(), bysample, String(sample))
        haskey(d, String(variation)) &&
            throw(ArgumentError("duplicate histogram for ($sample, $variation)"))
        d[String(variation)] = as_binned(value)
    end
    out = Dict{String,SampleTemplates}()
    for (sample, d) in bysample
        haskey(d, nominal) || throw(ArgumentError("sample $sample has no \"$nominal\" histogram"))
        nom = pop!(d, nominal)
        out[sample] = SampleTemplates(sample, nom, d)
    end
    return out
end

as_binned(h::BinnedHist) = h
as_binned(h::Hist1D) = binned_hist(h)
function as_binned(t::Tuple)
    length(t) == 3 || throw(ArgumentError("expected an (edges, sumw, sumw2) tuple"))
    return binned_hist(t...)
end
as_binned(t::NamedTuple) = binned_hist(t.edges, t.sumw, t.sumw2;
                                       underflow=get(t, :underflow, (0.0, 0.0)),
                                       overflow=get(t, :overflow, (0.0, 0.0)))
as_binned(x) = throw(ArgumentError("unsupported histogram input of type $(typeof(x))"))
