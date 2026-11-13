const _FIT_KEYS = ("channels", "poi", "poi_init", "poi_bounds", "signal", "grouping", "groups", "data",
                  "normsys", "histosys", "histosys_exclude", "histosys_prune", "staterror", "normsys_code",
                  "histosys_code", "impacts", "upper_limit", "significance", "profile_interval", "asimov")

"""
    fit_config(cfg::AnalysisConfig) -> Union{FitConfig,Nothing}
    fit_config(section::AbstractDict, samples::AbstractVector{SampleConfig}) -> FitConfig

Resolve the `[fit]` section of an analysis (`nothing` when the analysis has
none). Schema (defaults in parentheses):

```toml
[fit]
poi = "mu_ttbar"                  # ("mu") normfactor on the signal samples
signal = ["ttbar"]                # fit samples carrying the POI (required)
poi_init = 1.0                    # (1.0)
poi_bounds = [0.0, 10.0]          # ([0, 10])
grouping = "group"                # ("group") fit samples = sample groups; "sample" = one per sample
data = ["MuonEG"]                 # (all data samples)
channels = [{ region = "emu_ge1j", variable = "njet" }]   # optional "name" per channel
staterror = true                  # (true) Barlow-Beeston lite from sumw2
histosys = true                   # (true) from <name>Up / <name>Down histograms
histosys_exclude = []             # variation names not used as histosys
histosys_prune = 0.0              # (0) drop if max |shift| / nominal <= value
normsys_code = "code4"            # pyhf defaults
histosys_code = "code4p"
impacts = true                    # (true)
profile_interval = true           # (true) Δ(2 NLL) = 1 interval of the POI
upper_limit = false               # (false) asymptotic CLs 95% upper limit
significance = false              # (false) asymptotic discovery significance
asimov = false                    # (false) fit the pre-fit Asimov dataset

[fit.groups]                      # optional explicit fit samples (replaces grouping)
ttbar = ["TTto2L2Nu", "TTtoLNu2Q"]

[[fit.normsys]]
name = "lumi"
size = 0.014                      # or hi = 1.014, lo = 0.986
samples = ["all"]                 # fit sample names, "all" = every fit sample
placeholder = false
```

With `grouping = "group"` the fit samples are the distinct `group` values of
the simulated samples (a sample without group forms its own), in configuration
order.
"""
function fit_config(cfg::AnalysisConfig)
    haskey(cfg.raw, "fit") || return nothing
    return fit_config(cfg.raw["fit"], cfg.samples)
end

function fit_config(section::AbstractDict, samples::AbstractVector{SampleConfig})
    for k in keys(section)
        String(k) in _FIT_KEYS || throw(ArgumentError("unknown [fit] key '$k'"))
    end
    mc = [s for s in samples if is_mc(s)]
    fsamples = _fit_samples(section, mc)
    names = [f.name for f in fsamples]
    data = haskey(section, "data") ? String.(section["data"]) : [s.name for s in samples if is_data(s)]
    known = Set(s.name for s in samples)
    for d in data
        d in known || throw(ArgumentError("[fit] data sample '$d' is not an analysis sample"))
    end
    haskey(section, "channels") && !isempty(section["channels"]) ||
        throw(ArgumentError("[fit] needs at least one channel { region, variable }"))
    channels = FitChannel[]
    for c in section["channels"]
        haskey(c, "region") && haskey(c, "variable") || throw(ArgumentError("[fit] channel needs region and variable"))
        r, v = String(c["region"]), String(c["variable"])
        push!(channels, FitChannel(String(get(c, "name", r * "_" * v)), r, v))
    end
    allunique([c.name for c in channels]) || throw(ArgumentError("[fit] channel names must be unique"))
    haskey(section, "signal") || throw(ArgumentError("[fit] needs signal = [fit sample names]"))
    signal = String.(section["signal"] isa AbstractString ? [section["signal"]] : section["signal"])
    for s in signal
        s in names || throw(ArgumentError("[fit] signal '$s' is not a fit sample (have $(join(names, ", ")))"))
    end
    b = get(section, "poi_bounds", [0.0, 10.0])
    length(b) == 2 && b[1] < b[2] || throw(ArgumentError("[fit] poi_bounds must be [lo, hi] with lo < hi"))
    normsys = [_normsys_spec(n, names) for n in get(section, "normsys", Any[])]
    allunique([n.name for n in normsys]) || throw(ArgumentError("[fit] normsys names must be unique"))
    code(key, default, allowed) = begin
        c = Symbol(get(section, key, default))
        c in allowed || throw(ArgumentError("[fit] $key must be one of $(join(allowed, ", "))"))
        c
    end
    return FitConfig(channels, fsamples, data, String(get(section, "poi", "mu")), Float64(get(section, "poi_init", 1.0)),
                     (Float64(b[1]), Float64(b[2])), signal, normsys, Bool(get(section, "histosys", true)),
                     String.(get(section, "histosys_exclude", String[])), Float64(get(section, "histosys_prune", 0.0)),
                     Bool(get(section, "staterror", true)), code("normsys_code", "code4", (:code1, :code4)),
                     code("histosys_code", "code4p", (:code0, :code4p)), Bool(get(section, "impacts", true)),
                     Bool(get(section, "upper_limit", false)), Bool(get(section, "significance", false)),
                     Bool(get(section, "profile_interval", true)), Bool(get(section, "asimov", false)))
end

function _fit_samples(section, mc)
    if haskey(section, "groups")
        mcnames = Set(s.name for s in mc)
        out = FitSample[]
        for (g, members) in section["groups"]
            ms = String.(members)
            for m in ms
                m in mcnames || throw(ArgumentError("[fit.groups] $g: '$m' is not a simulated sample"))
            end
            push!(out, FitSample(String(g), ms))
        end
        sort!(out; by = f -> findfirst(s -> s.name == first(f.members), mc))
        allunique(reduce(vcat, (f.members for f in out); init = String[])) ||
            throw(ArgumentError("[fit.groups] a sample belongs to more than one group"))
        return out
    end
    grouping = String(get(section, "grouping", "group"))
    grouping in ("group", "sample") || throw(ArgumentError("[fit] grouping must be \"group\" or \"sample\""))
    order = String[]
    members = Dict{String,Vector{String}}()
    for s in mc
        g = grouping == "sample" || isempty(s.group) ? s.name : s.group
        haskey(members, g) || (push!(order, g); members[g] = String[])
        push!(members[g], s.name)
    end
    isempty(order) && throw(ArgumentError("[fit] the analysis has no simulated samples"))
    return [FitSample(g, members[g]) for g in order]
end

function _normsys_spec(n, names)
    haskey(n, "name") || throw(ArgumentError("[[fit.normsys]] needs a name"))
    name = String(n["name"])
    if haskey(n, "size")
        (haskey(n, "hi") || haskey(n, "lo")) && throw(ArgumentError("normsys $name: give size or hi/lo, not both"))
        k = Float64(n["size"])
        hi, lo = 1 + k, 1 - k
    else
        haskey(n, "hi") && haskey(n, "lo") || throw(ArgumentError("normsys $name needs size or hi and lo"))
        hi, lo = Float64(n["hi"]), Float64(n["lo"])
    end
    hi > 0 && lo > 0 || throw(ArgumentError("normsys $name: factors must be positive"))
    raw = get(n, "samples", ["all"])
    list = String.(raw isa AbstractString ? [raw] : raw)
    samples = "all" in list ? String[] : list
    for s in samples
        s in names || throw(ArgumentError("normsys $name: '$s' is not a fit sample"))
    end
    return NormSysSpec(name, hi, lo, samples, Bool(get(n, "placeholder", false)))
end
