"Merge actual per-region counts from consecutive chunks in input order."
function merge_region_counts!(dest::AbstractDict, src::AbstractDict)
    for (name, counts) in src
        total = get!(dest, name, Dict{String,Any}("n" => 0, "sumw" => 0.0))
        total["n"] += counts["n"]
        total["sumw"] += counts["sumw"]
    end
    return dest
end
