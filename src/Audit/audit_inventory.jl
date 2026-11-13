"Discover every configured pattern independently, preserving production paths and aliases."
function audit_inventory(s::SampleConfig, findings)
    patterns = Any[]; files = String[]; occurrences = Dict{String,Int}()
    for pattern in s.files
        matches = try
            expand_files([pattern])
        catch e
            audit_finding!(findings, "error", "invalid_pattern", sprint(showerror, e); sample = s.name, path = pattern)
            String[]
        end
        isempty(matches) && audit_finding!(findings, "error", "unmatched_pattern", "configured pattern matches no input files"; sample = s.name, path = pattern)
        push!(patterns, Dict("pattern" => pattern, "matches" => matches))
        for f in matches
            occurrences[f] = get(occurrences, f, 0) + 1
            push!(files, f)
        end
    end
    files = sort!(unique(files)) # Exactly the production expansion/deduplication policy.
    for (f, n) in sort!(collect(occurrences); by = first)
        n > 1 && audit_finding!(findings, "warning", "repeated_pattern_match", "identical input path occurs in multiple patterns; production expands it once";
            sample = s.name, path = f, observed = n)
    end
    isempty(files) && audit_finding!(findings, "error", "empty_inventory", "sample has no discovered inputs"; sample = s.name)
    records = Any[]
    for f in files
        record = Dict{String,Any}("path" => f, "exists" => false, "realpath" => nothing,
            "identity" => nothing, "signature" => nothing)
        try
            signature = file_signature(f)
            st = stat(f)
            real = realpath(f)
            identity = hasproperty(st, :device) && hasproperty(st, :inode) && st.inode != 0 ?
                string("inode:", st.device, ":", st.inode) : "realpath:" * real
            merge!(record, Dict("exists" => true, "realpath" => real, "identity" => identity, "signature" => signature))
        catch e
            audit_finding!(findings, "error", "missing_or_invalid_file", sprint(showerror, e); sample = s.name, path = f)
        end
        push!(records, record)
    end
    return Dict{String,Any}("patterns" => patterns, "files" => records, "discovered_nfiles" => length(files))
end
