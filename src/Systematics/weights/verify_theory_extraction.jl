"""
    verify_theory_extraction(cfg, store)

Verify persisted raw-member extraction claims against the current configuration
before reduction/consumer use. Reduction-only edits remain compatible. Only
samples represented by the store or its empty-selection records are required.
"""
function verify_theory_extraction(cfg,store::HistogramStore)
    stored=get(store.meta,"theory_extraction",Dict{String,Any}())
    validate_theory_manifest(stored,[(k.sample,k.variation) for k in keys(store)])
    expected=theory_extraction(cfg)
    represented=union(Set(k.sample for k in keys(store)),Set(String.(keys(stored))))
    for s in represented
        canonical_hash(get(stored,s,nothing))==canonical_hash(get(expected,s,nothing)) ||
            throw(ArgumentError("stale/missing theory extraction contract for $s; rerun correct/histogram/merge before systematics/plot"))
    end
    return nothing
end
