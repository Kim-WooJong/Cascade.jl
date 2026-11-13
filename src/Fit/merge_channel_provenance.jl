"""
    merge_channel_provenance!(dest::AbstractDict, src::AbstractDict) -> dest

Merge exact overlap counts from independent nominal data chunks. `dest` may
initially be empty; channel definitions must agree. Attach the result to
`HistogramStore.meta["fit_channel_provenance"]` before building a workspace.
"""
function merge_channel_provenance!(dest::AbstractDict, src::AbstractDict)
    if isempty(dest)
        merge!(dest, deepcopy(src))
        return dest
    end
    dest["version"] == src["version"] == 1 && dest["channels"] == src["channels"] ||
        throw(ArgumentError("cannot merge incompatible fit channel overlap provenance"))
    for (sample, record) in src["samples"]
        if !haskey(dest["samples"], sample)
            dest["samples"][sample] = deepcopy(record)
            continue
        end
        target = dest["samples"][sample]
        for (ch, n) in record["channel_events"]
            target["channel_events"][ch] += Int(n)
        end
        for pair in record["overlaps"]
            idx = findfirst(p -> p["left"] == pair["left"] && p["right"] == pair["right"], target["overlaps"])
            idx === nothing && throw(ArgumentError("incomplete fit channel overlap provenance"))
            target["overlaps"][idx]["n"] += Int(pair["n"])
        end
    end
    return dest
end
