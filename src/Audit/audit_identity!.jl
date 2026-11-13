"Find repeated physical input membership; this does not inspect collision IDs or copied content."
function audit_identity!(inventories, selected, findings)
    members = Dict{String,Vector{Tuple{String,String}}}()
    for (sample, inventory) in inventories, file in inventory["files"]
        file["identity"] === nothing && continue
        push!(get!(members, file["identity"], Tuple{String,String}[]), (sample, file["path"]))
    end
    for (identity, owners) in sort!(collect(members); by = first)
        length(owners) > 1 && any(o -> first(o) in selected, owners) || continue
        owners = sort!(owners)
        names = unique(first.(owners))
        code = length(names) > 1 ? "cross_sample_file" : "physical_file_alias"
        audit_finding!(findings, "error", code,
            "same physical input is assigned more than once; production paths are not silently rewritten";
            sample = join(names, ","), path = identity, observed = [Dict("sample" => s, "path" => p) for (s,p) in owners])
    end
    return nothing
end
