"""
    region_counts(table::EventTable) -> Dict

Unweighted counts and base-weight sums for actual region membership (not just
the sequential cut prefix). Used for region yields and shape diagnostics.
"""
function region_counts(table::EventTable)
    w = table["weight"]
    out = Dict{String,Any}()
    for (r, mask) in region_masks(table)
        n = 0
        total = 0.0
        for i in eachindex(mask)
            mask[i] || continue
            n += 1
            total += w[i]
        end
        out[r] = Dict("n" => n, "sumw" => total)
    end
    return out
end
