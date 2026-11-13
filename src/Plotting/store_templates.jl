"""
    store_templates(store::HistogramStore, region, variable; samples=nothing) -> Dict{String,SampleTemplates}

Per-sample [`SampleTemplates`](@ref) of `variable` in `region` taken directly
from a `Cascade.Histograms` store: the `"nominal"` histogram and every other
variation label (`"<name>Up"`/`"<name>Down"`) of each sample (restricted to
`samples` when given). Samples without a nominal histogram are skipped.
"""
function store_templates(store::HistogramStore, region::AbstractString, variable::AbstractString; samples = nothing)
    bysample = Dict{String,Dict{String,BinnedHist}}()
    for (k, h) in store.hists
        k.region == region && k.variable == variable || continue
        samples === nothing || k.sample in samples || continue
        get!(() -> Dict{String,BinnedHist}(), bysample, k.sample)[k.variation] = h
    end
    out = Dict{String,SampleTemplates}()
    for (s, d) in bysample
        haskey(d, NOMINAL) || continue
        nom = pop!(d, NOMINAL)
        out[s] = SampleTemplates(s, nom, d)
    end
    return out
end
