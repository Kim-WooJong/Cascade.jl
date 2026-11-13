"""
    build_workspace(store::HistogramStore, fc::FitConfig) -> (workspace, channels, notes)

pyhf-compatible workspace (JSON schema 1.0.0: `channels`, `observations`,
`measurements`, `version`) built from the histograms of `store`:

- one channel per `fc.channels` entry (region x variable), one workspace sample
  per fit sample: the sum of the nominal histograms of its members present in
  the store (a fit sample without any member histogram is left out of that
  channel);
- modifiers: `normfactor` `fc.poi` on the signal samples; `normsys` from
  `fc.normsys`; `histosys` (when `fc.histosys`) for every variation name pair
  `<name>Up`/`<name>Down` found for a member (members without the variation
  contribute their nominal; a one-sided variation is mirrored around the
  nominal, `down = 2 nominal - up`; identical templates and those within
  `fc.histosys_prune` are dropped); `staterror` `staterror_<channel>` with
  `sqrt(Σ sumw2)` per bin (when `fc.staterror`);
- observations: the summed nominal histograms of `fc.data` (zeros when no data
  sample is configured); when `fc.asimov`, replace these with expected counts
  at the initial parameters, matching the fitted dataset;
- measurement `"cascade"` with the POI, its init and bounds.

`channels` gives per channel `(name, region, variable, edges, members, histosys)`
(`members`: fit sample => store samples used); `notes` lists dropped or
mirrored items.
"""
function build_workspace(store::HistogramStore, fc::FitConfig)
    validate_channel_disjointness(store, fc)
    notes = String[]
    normnames = Set(n.name for n in fc.normsys)
    wchannels = Any[]
    observations = Any[]
    info = NamedTuple[]
    for ch in fc.channels
        keys_ch = [k for k in keys(store) if k.region == ch.region && k.variable == ch.variable]
        isempty(keys_ch) && throw(ArgumentError("fit channel $(ch.name): no histogram $(ch.variable) in region $(ch.region)"))
        edges = store[first(keys_ch)].edges
        samples = Any[]
        members_used = Dict{String,Vector{String}}()
        histosys_used = String[]
        for fs in fc.samples
            present = [m for m in fs.members if haskey(store, HistKey(ch.region, m, NOMINAL, ch.variable))]
            if isempty(present)
                push!(notes, "channel $(ch.name): fit sample $(fs.name) has no histogram, left out")
                continue
            end
            members_used[fs.name] = present
            hs = [store[ch.region, m, NOMINAL, ch.variable] for m in present]
            all(h -> h.edges == edges, hs) || throw(ArgumentError("fit channel $(ch.name): bin edges differ between samples"))
            nom = reduce(+, (h.sumw for h in hs); init = zeros(length(edges) - 1))
            var = reduce(+, (h.sumw2 for h in hs); init = zeros(length(edges) - 1))
            mods = Any[]
            fs.name in fc.signal && push!(mods, Dict("name" => fc.poi, "type" => "normfactor", "data" => nothing))
            for n in fc.normsys
                (isempty(n.samples) || fs.name in n.samples) &&
                    push!(mods, Dict("name" => n.name, "type" => "normsys", "data" => Dict("hi" => n.hi, "lo" => n.lo)))
            end
            if fc.histosys
                for (name, up, dn, mirrored) in _histosys_templates(store, ch, present, nom)
                    if name in normnames || name == fc.poi
                        push!(notes, "channel $(ch.name): variation $name has the name of a normsys/POI, not used as histosys")
                        continue
                    end
                    name in fc.histosys_exclude && continue
                    shift = max(maximum(abs.(up .- nom); init = 0.0), maximum(abs.(dn .- nom); init = 0.0))
                    shift == 0 && continue
                    rel = maximum((nom[b] == 0 ? (up[b] == dn[b] == 0 ? 0.0 : Inf) :
                                   max(abs(up[b] - nom[b]), abs(dn[b] - nom[b])) / abs(nom[b])
                                   for b in eachindex(nom)); init = 0.0)
                    if rel <= fc.histosys_prune
                        push!(notes, "channel $(ch.name): histosys $name on $(fs.name) pruned (max rel. shift $rel)")
                        continue
                    end
                    mirrored && push!(notes, "channel $(ch.name): histosys $name on $(fs.name) is one-sided, mirrored")
                    push!(mods, Dict("name" => name, "type" => "histosys", "data" => Dict("hi_data" => up, "lo_data" => dn)))
                    name in histosys_used || push!(histosys_used, name)
                end
            end
            fc.staterror && push!(mods, Dict("name" => "staterror_" * ch.name, "type" => "staterror",
                                             "data" => sqrt.(var)))
            push!(samples, Dict("name" => fs.name, "data" => nom, "modifiers" => mods))
        end
        isempty(samples) && throw(ArgumentError("fit channel $(ch.name) has no simulated sample"))
        obs = zeros(length(edges) - 1)
        for d in fc.data
            k = HistKey(ch.region, d, NOMINAL, ch.variable)
            haskey(store, k) || (push!(notes, "channel $(ch.name): no data histogram for $d"); continue)
            obs .+= store[k].sumw
        end
        push!(wchannels, Dict("name" => ch.name, "samples" => samples))
        push!(observations, Dict("name" => ch.name, "data" => obs))
        push!(info, (name = ch.name, region = ch.region, variable = ch.variable, edges = copy(edges),
                     members = members_used, histosys = sort!(histosys_used)))
    end
    any(c -> any(s -> any(m -> m["type"] == "normfactor", s["modifiers"]), c["samples"]), wchannels) ||
        throw(ArgumentError("no signal sample of $(fc.signal) is present in any fit channel"))
    meas = Dict("name" => "cascade", "config" => Dict("poi" => fc.poi, "parameters" => Any[
        Dict("name" => fc.poi, "inits" => [fc.poi_init], "bounds" => [[fc.poi_bounds[1], fc.poi_bounds[2]]])]))
    ws = Dict{String,Any}("channels" => wchannels, "observations" => observations, "measurements" => Any[meas],
                          "version" => "1.0.0")
    if fc.asimov
        model = HistModel(ws; normsys_code = fc.normsys_code, histosys_code = fc.histosys_code)
        data = asimov_data(model, [p.init for p in model.parameters])
        for obs in observations
            ci = findfirst(==(obs["name"]), model.channels)
            obs["data"] = copy(data.main[model.channel_bins[ci]])
        end
    end
    return (workspace = ws, channels = info, notes = notes)
end

# (name, up, down, mirrored) for every variation name of the members in this channel.
function _histosys_templates(store, ch, members, nom)
    labels = Set{String}()
    for k in keys(store)
        k.region == ch.region && k.variable == ch.variable && k.sample in members && k.variation != NOMINAL &&
            push!(labels, k.variation)
    end
    bases = sort!(unique([_variation_base(v) for v in labels if _variation_base(v) !== nothing]))
    out = Tuple{String,Vector{Float64},Vector{Float64},Bool}[]
    for b in bases
        hasup, hasdn = b * "Up" in labels, b * "Down" in labels
        total(label) = reduce(+, (begin
            k = HistKey(ch.region, m, label, ch.variable)
            haskey(store, k) ? store[k].sumw : store[ch.region, m, NOMINAL, ch.variable].sumw
        end for m in members); init = zeros(length(nom)))
        up = hasup ? total(b * "Up") : nothing
        dn = hasdn ? total(b * "Down") : nothing
        up === nothing && (up = 2 .* nom .- dn)
        dn === nothing && (dn = 2 .* nom .- up)
        push!(out, (b, up, dn, !(hasup && hasdn)))
    end
    return out
end

function _variation_base(v::AbstractString)
    endswith(v, "Up") && length(v) > 2 && return String(v[1:end-2])
    endswith(v, "Down") && length(v) > 4 && return String(v[1:end-4])
    return nothing
end
