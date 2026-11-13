const _SCALAR_KINDS = (:normfactor, :lumi, :normsys, :histosys)
const _BIN_KINDS = (:shapesys, :staterror, :shapefactor)

"""
    HistModel(spec; measurement=nothing, poi=nothing,
              normsys_code=:code4, histosys_code=:code4p)

Build a [`HistModel`](@ref) from a pyhf-style workspace dictionary
(see [`load_workspace`](@ref)). Supported modifiers: `normfactor`, `lumi`,
`normsys`, `histosys`, `shapesys`, `staterror`, `shapefactor`.

`measurement` selects a measurement by name (default: the first one); its
`config.poi` and `config.parameters` (inits, bounds, fixed, auxdata, sigmas)
are applied. `poi` overrides the parameter of interest.

Constraint conventions follow pyhf 0.7: normsys/histosys/lumi/staterror are
Gaussian; shapesys is Poisson with `tau = (nominal/uncertainty)^2`.
staterror/shapesys bins whose nominal (or uncertainty) is zero are fixed at 1.
"""
function HistModel(spec::AbstractDict; measurement=nothing, poi=nothing,
                   normsys_code::Symbol=:code4, histosys_code::Symbol=:code4p)
    spec = _plain(spec)
    channels = sort(spec["channels"]; by=c -> c["name"])
    meas = _select_measurement(spec, measurement)
    parcfg = Dict{String,Any}()
    if meas !== nothing
        for p in get(meas["config"], "parameters", Any[])
            parcfg[p["name"]] = p
        end
    end
    poi_name = poi !== nothing ? String(poi) :
               (meas !== nothing ? get(meas["config"], "poi", nothing) : nothing)

    # Pass 1: modifier inventory and per-bin statistics.
    kinds = Dict{String,Symbol}()
    nbins_of = Dict{String,Int}()
    chan_of = Dict{String,Int}()
    stat_nom = Dict{String,Vector{Float64}}()
    stat_var = Dict{String,Vector{Float64}}()
    shapesys_def = Dict{String,Tuple{Vector{Float64},Vector{Float64}}}()
    for (ci, ch) in enumerate(channels)
        for s in ch["samples"]
            nom = Float64.(s["data"])
            for m in s["modifiers"]
                name = m["name"]
                kind = Symbol(m["type"])
                kind in _SCALAR_KINDS || kind in _BIN_KINDS ||
                    throw(ArgumentError("unsupported modifier type $(m["type"]) ($name)"))
                haskey(kinds, name) && kinds[name] !== kind &&
                    throw(ArgumentError("modifier $name used with types $(kinds[name]) and $kind"))
                kinds[name] = kind
                kind in _BIN_KINDS || continue
                if haskey(nbins_of, name) && nbins_of[name] != length(nom)
                    throw(ArgumentError("per-bin modifier $name used with different bin counts"))
                end
                nbins_of[name] = length(nom)
                if kind === :staterror || kind === :shapesys
                    haskey(chan_of, name) && chan_of[name] != ci &&
                        throw(ArgumentError("$kind modifier $name shared across channels is not supported"))
                    chan_of[name] = ci
                end
                if kind === :staterror
                    unc = Float64.(m["data"])
                    nm = get!(stat_nom, name, zeros(length(nom)))
                    vr = get!(stat_var, name, zeros(length(nom)))
                    nm .+= nom
                    vr .+= unc .^ 2
                elseif kind === :shapesys
                    haskey(shapesys_def, name) &&
                        throw(ArgumentError("shapesys modifier $name used by more than one sample"))
                    shapesys_def[name] = (nom, Float64.(m["data"]))
                end
            end
        end
    end
    for (k, v) in parcfg
        haskey(kinds, k) || throw(ArgumentError("measurement config references unknown parameter $k"))
    end

    # Pass 2: parameter table, ordered by modifier name.
    params = ParameterInfo[]
    first_index = Dict{String,Int}()
    for name in sort(collect(keys(kinds)))
        kind = kinds[name]
        cfg = get(parcfg, name, Dict{String,Any}())
        first_index[name] = length(params) + 1
        if kind in _SCALAR_KINDS
            push!(params, _scalar_parameter(name, kind, cfg))
        else
            n = nbins_of[name]
            for b in 1:n
                push!(params, _bin_parameter(name, kind, b, n, cfg, stat_nom, stat_var, shapesys_def))
            end
        end
    end
    index = Dict(p.name => i for (i, p) in enumerate(params))
    poi_idx = 0
    if poi_name !== nothing && poi_name != ""
        haskey(index, poi_name) || throw(ArgumentError("POI $poi_name is not a model parameter"))
        poi_idx = index[poi_name]
    end

    # Pass 3: sample terms and observations.
    chan_names = String[]
    chan_bins = UnitRange{Int}[]
    samples = SampleTerm[]
    offset = 0
    for (ci, ch) in enumerate(channels)
        nb = length(ch["samples"][1]["data"])
        rng = (offset + 1):(offset + nb)
        push!(chan_names, ch["name"])
        push!(chan_bins, rng)
        for s in ch["samples"]
            nom = Float64.(s["data"])
            length(nom) == nb || throw(ArgumentError("sample $(s["name"]) in $(ch["name"]) has wrong bin count"))
            factors = Int[]
            normsys = NormSysTerm[]
            histosys = HistoSysTerm[]
            binfactors = Vector{Int}[]
            for m in s["modifiers"]
                name = m["name"]
                kind = kinds[name]
                p0 = first_index[name]
                if kind === :normfactor || kind === :lumi
                    push!(factors, p0)
                elseif kind === :normsys
                    hi = Float64(m["data"]["hi"])
                    lo = Float64(m["data"]["lo"])
                    push!(normsys, NormSysTerm(p0, hi, lo, normsys_code, code4_coefficients(hi, lo)))
                elseif kind === :histosys
                    up = Float64.(m["data"]["hi_data"])
                    dn = Float64.(m["data"]["lo_data"])
                    (length(up) == nb && length(dn) == nb) ||
                        throw(ArgumentError("histosys $name has wrong bin count"))
                    push!(histosys, HistoSysTerm(p0, up, dn, histosys_code))
                else
                    push!(binfactors, collect(p0:(p0 + nb - 1)))
                end
            end
            push!(samples, SampleTerm(s["name"], ci, rng, nom, factors, normsys, histosys, binfactors))
        end
        offset += nb
    end
    obs = Float64[]
    if haskey(spec, "observations")
        byname = Dict(o["name"] => Float64.(o["data"]) for o in spec["observations"])
        if all(n -> haskey(byname, n), chan_names)
            for (n, rng) in zip(chan_names, chan_bins)
                length(byname[n]) == length(rng) || throw(ArgumentError("observation $n has wrong bin count"))
                append!(obs, byname[n])
            end
        end
    end
    return HistModel(chan_names, chan_bins, samples, params, index, poi_idx, obs)
end

function _select_measurement(spec, measurement)
    ms = get(spec, "measurements", Any[])
    isempty(ms) && return nothing
    measurement === nothing && return ms[1]
    for m in ms
        m["name"] == measurement && return m
    end
    throw(ArgumentError("measurement $measurement not found"))
end

_cfg(cfg, key, i, default) = haskey(cfg, key) ? cfg[key][i] : default

function _scalar_parameter(name, kind, cfg)
    if kind === :normfactor
        init, lo, hi, con, aux, sig = 1.0, 0.0, 10.0, :none, NaN, NaN
    elseif kind === :lumi
        (haskey(cfg, "auxdata") && haskey(cfg, "sigmas")) ||
            throw(ArgumentError("lumi modifier $name needs auxdata and sigmas in the measurement config"))
        aux = Float64(cfg["auxdata"][1])
        sig = Float64(cfg["sigmas"][1])
        init, lo, hi, con = aux, 0.0, 10.0, :gauss
    else
        init, lo, hi, con, aux, sig = 0.0, -5.0, 5.0, :gauss, 0.0, 1.0
        haskey(cfg, "auxdata") && (aux = Float64(cfg["auxdata"][1]))
        haskey(cfg, "sigmas") && (sig = Float64(cfg["sigmas"][1]))
    end
    init = Float64(_cfg(cfg, "inits", 1, init))
    b = _cfg(cfg, "bounds", 1, [lo, hi])
    fixed = Bool(get(cfg, "fixed", false))
    return ParameterInfo(name, name, kind, init, Float64(b[1]), Float64(b[2]), fixed, con, aux, sig, NaN)
end

function _bin_parameter(name, kind, b, n, cfg, stat_nom, stat_var, shapesys_def)
    pname = "$name[$(b - 1)]"
    init, lo, hi, fixed = 1.0, 1e-10, 10.0, false
    con, aux, sig, tau = :none, NaN, NaN, NaN
    if kind === :shapefactor
        lo = 0.0
    elseif kind === :staterror
        nom = stat_nom[name][b]
        rel = nom > 0 ? sqrt(stat_var[name][b]) / nom : 0.0
        con, aux = :gauss, 1.0
        if rel > 0
            sig = rel
        else
            sig, fixed = 1.0, true
        end
        haskey(cfg, "sigmas") && (sig = Float64(cfg["sigmas"][b]))
    elseif kind === :shapesys
        nom, unc = shapesys_def[name][1][b], shapesys_def[name][2][b]
        con = :poisson
        if nom > 0 && unc > 0
            tau = (nom / unc)^2
        else
            tau, fixed = 1.0, true
        end
        aux, sig = tau, 1 / sqrt(tau)
    end
    init = Float64(_cfg(cfg, "inits", b, init))
    bb = _cfg(cfg, "bounds", b, [lo, hi])
    fixed = fixed || Bool(get(cfg, "fixed", false))
    return ParameterInfo(pname, name, kind, init, Float64(bb[1]), Float64(bb[2]), fixed, con, aux, sig, tau)
end
