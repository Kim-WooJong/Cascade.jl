"""
    stack_config(path::AbstractString) -> StackConfig
    stack_config(cfg::AbstractDict) -> StackConfig

Read the sample grouping and colours from a TOML file or a parsed dictionary.
A top-level `plotting` table is used when present:

```toml
[plotting]
data = ["MuonEG", "Muon"]

[[plotting.groups]]          # bottom of the stack first
label = "Z + jets"
color = "#1F77B4"
samples = ["DYto2L_MLL50", "DYto2L_MLL10to50"]
```
"""
stack_config(path::AbstractString) = stack_config(TOML.parsefile(path))

function stack_config(cfg::AbstractDict)
    c = haskey(cfg, "plotting") ? cfg["plotting"] : cfg
    haskey(c, "groups") || throw(ArgumentError("plotting configuration has no groups"))
    groups = SampleGroup[]
    for g in c["groups"]
        for key in ("label", "color", "samples")
            haskey(g, key) || throw(ArgumentError("plotting group without \"$key\""))
        end
        push!(groups, SampleGroup(g["label"], g["color"], g["samples"]))
    end
    return StackConfig(groups, String.(get(c, "data", String[])))
end
