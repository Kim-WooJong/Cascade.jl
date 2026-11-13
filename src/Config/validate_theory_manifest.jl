"""
    validate_theory_manifest(manifest, members) -> manifest

Check persisted extraction records and internal (sample, label) pairs. No
current configuration is stamped onto the values. Used before propagation or
merge; contract hashes detect malformed/foreign metadata, not malicious edits.
"""
function validate_theory_manifest(manifest, members)
    manifest isa AbstractDict || throw(ArgumentError("invalid theory extraction manifest"))
    expected=Dict{String,Set{String}}()
    for (sample,record) in manifest
        record isa AbstractDict || throw(ArgumentError("invalid theory extraction record"))
        c=get(record,"contract",nothing)
        c isa AbstractDict && get(c,"version",0)==1 && get(c,"sample",nothing)==sample &&
            get(record,"hash",nothing)==canonical_hash(c) ||
            throw(ArgumentError("invalid/foreign theory extraction contract for $sample"))
        labels=Set{String}()
        for t in get(c,"terms",Any[]), i in t["indices"]
            push!(labels,"__theory_$(t["name"])_$i")
        end
        isempty(labels) && throw(ArgumentError("empty theory extraction contract for $sample"))
        expected[String(sample)]=labels
    end
    actual=Dict{String,Set{String}}()
    for (s,label) in members
        startswith(label,"__theory_") || continue
        push!(get!(actual,String(s),Set{String}()),String(label))
    end
    for (s,labels) in actual
        get(expected,s,nothing)==labels || throw(ArgumentError(
            "missing/incompatible theory extraction contract for $s; rerun correct/histogram/merge"))
    end
    return manifest
end
