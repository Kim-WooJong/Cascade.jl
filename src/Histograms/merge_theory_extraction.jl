"""
    merge_theory_extraction!(dest, src)

Validate member provenance before histogram mutation; reject incompatible or
missing contracts for overlapping samples. Preserve disjoint/empty sample
records without overwriting another chunk's extraction claim.
"""
function merge_theory_extraction!(dest::HistogramStore,src::HistogramStore)
    a=get(dest.meta,"theory_extraction",Dict{String,Any}())
    b=get(src.meta,"theory_extraction",Dict{String,Any}())
    validate_theory_manifest(a,[(k.sample,k.variation) for k in keys(dest)])
    validate_theory_manifest(b,[(k.sample,k.variation) for k in keys(src)])
    sa=union(Set(k.sample for k in keys(dest)),Set(String.(keys(a))))
    sb=union(Set(k.sample for k in keys(src)),Set(String.(keys(b))))
    for s in intersect(sa,sb)
        canonical_hash(get(a,s,nothing))==canonical_hash(get(b,s,nothing)) ||
            throw(ArgumentError("incompatible theory extraction contracts across chunks for $s"))
    end
    merged=deepcopy(a)
    for (s,record) in b
        merged[s]=deepcopy(record)
    end
    isempty(merged) || (dest.meta["theory_extraction"]=merged)
    return dest
end
