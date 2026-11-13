"""
    Cascade.Histograms

Histogram store indexed by region x sample x variation x variable. Each entry
is a `BinnedHist` (edges, sumw, sumw2) — the same content as a ROOTPlots
`Hist1D(edges, sumw, sumw2)`, so plotting converts with `hist_arrays` without
this module depending on ROOTPlots. Stores are mergeable, scalable and
serialised to JSON with bit-exact Float64 round trip.
"""
module Histograms

using JSON3
using ..Config: HistogramConfig, validate_theory_manifest, canonical_hash

include("BinnedHist.jl")
include("fill_bin.jl")
include("HistKey.jl")
include("variation_label.jl")
include("HistogramStore.jl")
include("fill_store.jl")
include("merge_theory_extraction.jl")
include("merge_store.jl")
include("scale_store.jl")
include("filter_store.jl")
include("hist_arrays.jl")
include("luminosity_scale.jl")
include("write_store.jl")
include("read_store.jl")

export BinnedHist, fill_bin!, integral, HistKey, NOMINAL, variation_label,
       HistogramStore, hist!, store_axis, fill_store!, merge_store!, scale_store!,
       filter_store, hist_arrays, luminosity_scale, write_store, read_store

end # module
