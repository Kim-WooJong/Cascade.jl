"""
    parse_corrections(cfg::AnalysisConfig) -> CorrectionsSpec

Parse and check the `[corrections]` section (missing section: empty spec).
Schema (all names are free labels unless stated):

    [corrections.sets]                 # alias = correctionlib file (\${paths} allowed,
    muon = "\${jsonpog}/MUO/2022_Summer22/muon_Z.json.gz"   # relative to the TOML)

    [[corrections.object_sf]]          # product over selected objects
    name = "muon_id"                   # variation label: muon_idUp / muon_idDown
    set = "muon"                       # alias from [corrections.sets]
    correction = "NUM_TightID_DEN_TrackerMuons"
    object = "muons"                   # an [[objects]] name
    indices = [1]                      # selected objects (1 = leading)
    when = "pt < 75.0"                 # optional object condition (else factor 1)
    inputs = { eta = "eta", pt = "pt" }  # constants or object expressions
    systematic = "scale_factors"       # string input selecting the value type
    nominal = "nominal"                # its keys; up/down optional (both or none)
    up = "systup"
    down = "systdown"

    [[corrections.event_weight]]       # per-event factor, same keys minus
    name = "pileup"                    # object/indices/when; expressions are
    ...                                # event scope (branches, output variables)

    [[corrections.flat]]               # constant factors (placeholders)
    name = "trigger"
    nominal = 1.0
    up = 1.02
    down = 0.98

    # Optional independent-single-path trigger OR from separate data/MC
    # efficiencies: see docs/TRIGGERS.md for [[corrections.trigger_or]].

Inputs: a TOML string for a `string`-typed correction input is a constant
(e.g. `year = "2022Re-recoBCD"`); for `real`/`int` inputs a number is a
constant and a string is an expression (whitelisted functions: arithmetic,
comparisons, `abs`, `min`, `max`, `sqrt`, ...). In object scope a field
`f` of object `o` at index `k` (and any sub-expression) is taken from an
`[output] columns` variable whose expression is `o.f[k]` (resp. the
substituted sub-expression, so `eta + deltaEtaSC` can use a variable
`electrons.eta[1] + electrons.deltaEtaSC[1]` computed at selection time in
NanoAOD precision). In event scope a name is an `[output] columns`
variable or a branch of the source file. Terms sharing a `name` form one
variation (varied together). Corrections apply to MC samples only; data keeps
the base weight. Throws `ArgumentError` listing every problem found.
"""
function parse_corrections(cfg::AnalysisConfig)
    raw = get(cfg.raw, "corrections", nothing)
    raw === nothing && return CorrectionsSpec()
    errs = String[]
    raw isa AbstractDict || throw(ArgumentError("[corrections] must be a table"))
    _unknown_keys!(errs, "corrections", raw, ("sets", "object_sf", "event_weight", "flat", "trigger_or"))
    paths = get(cfg.raw, "paths", Dict{String,Any}())
    sets = Dict{String,String}()
    for (k, p) in get(raw, "sets", Dict{String,Any}())
        if p isa AbstractString
            q = substitute_paths(p, paths)
            sets[String(k)] = isabspath(q) ? q : normpath(joinpath(cfg.dir, q))
        else
            push!(errs, "corrections.sets.$k must be a file path string")
        end
    end
    objects = Set(o.name for o in cfg.objects)
    exprvars = Set(v.name for v in cfg.variations)

    osfs = ObjectScaleFactor[]
    for (i, t) in enumerate(get(raw, "object_sf", Any[]))
        w = "corrections.object_sf[$i]"
        _unknown_keys!(errs, w, t, ("name", "set", "correction", "object", "indices", "when", "inputs",
                                    "systematic", "nominal", "up", "down"))
        name, set, corr, inputs, syst, keys = _common!(errs, w, t, sets, exprvars)
        obj = _string!(errs, w, t, "object")
        isempty(obj) || obj in objects || push!(errs, "$w: unknown object '$obj'")
        idx = get(t, "indices", nothing)
        indices = Int[]
        if idx isa AbstractVector && !isempty(idx) && all(x -> x isa Integer && x >= 1, idx)
            indices = Int.(idx)
        else
            push!(errs, "$w: indices must be a non-empty list of positive integers")
        end
        when = String(get(t, "when", ""))
        if !isempty(when)
            try
                parse_expression(when)
            catch e
                push!(errs, "$w: when: $(sprint(showerror, e))")
            end
        end
        push!(osfs, ObjectScaleFactor(name, set, corr, obj, indices, when, inputs, syst, keys))
    end

    evws = EventWeight[]
    for (i, t) in enumerate(get(raw, "event_weight", Any[]))
        w = "corrections.event_weight[$i]"
        _unknown_keys!(errs, w, t, ("name", "set", "correction", "inputs", "systematic", "nominal", "up", "down"))
        name, set, corr, inputs, syst, keys = _common!(errs, w, t, sets, exprvars)
        push!(evws, EventWeight(name, set, corr, inputs, syst, keys))
    end

    flat = FlatWeight[]
    for (i, t) in enumerate(get(raw, "flat", Any[]))
        w = "corrections.flat[$i]"
        _unknown_keys!(errs, w, t, ("name", "nominal", "up", "down"))
        name = _name!(errs, w, t, exprvars)
        vals = Float64[]
        for (k, d) in (("nominal", 1.0), ("up", nothing), ("down", nothing))
            x = get(t, k, d)
            if x isa Real && !(x isa Bool) && isfinite(x)
                push!(vals, Float64(x))
            else
                push!(errs, "$w: $k must be a finite number"); push!(vals, NaN)
            end
        end
        push!(flat, FlatWeight(name, vals[1], vals[2], vals[3]))
    end
    trigger_ors = parse_trigger_or(get(raw, "trigger_or", Any[]), sets, objects, exprvars, errs)
    isempty(errs) || throw(ArgumentError("invalid [corrections]:\n  " * join(errs, "\n  ")))
    return CorrectionsSpec(sets, osfs, evws, flat, trigger_ors)
end

function _unknown_keys!(errs, label, t, allowed)
    t isa AbstractDict || (push!(errs, "$label must be a table"); return)
    for k in keys(t)
        String(k) in allowed || push!(errs, "$label: unknown key '$k'")
    end
end

function _string!(errs, label, t, key)
    t isa AbstractDict || return ""
    x = get(t, key, nothing)
    x isa AbstractString && !isempty(x) && return String(x)
    push!(errs, "$label: $key must be a non-empty string")
    return ""
end

function _name!(errs, label, t, exprvars)
    name = _string!(errs, label, t, "name")
    occursin(r"^[A-Za-z_][A-Za-z0-9_]*$", name) || isempty(name) ||
        push!(errs, "$label: name '$name' must be an identifier")
    name == "nominal" && push!(errs, "$label: name 'nominal' is reserved")
    name in exprvars && push!(errs, "$label: name '$name' is also a [weights] variation")
    return name
end

function _common!(errs, label, t, sets, exprvars)
    name = _name!(errs, label, t, exprvars)
    alias = _string!(errs, label, t, "set")
    set = get(sets, alias, "")
    isempty(alias) || haskey(sets, alias) || push!(errs, "$label: unknown set '$alias'")
    corr = _string!(errs, label, t, "correction")
    inputs = Dict{String,Any}()
    raw = t isa AbstractDict ? get(t, "inputs", Dict{String,Any}()) : Dict{String,Any}()
    if raw isa AbstractDict
        for (k, v) in raw
            if v isa AbstractString || (v isa Real && !(v isa Bool))
                inputs[String(k)] = v isa AbstractString ? String(v) : v
            else
                push!(errs, "$label: input '$k' must be a string or a number")
            end
        end
    else
        push!(errs, "$label: inputs must be a table")
    end
    syst = t isa AbstractDict ? String(get(t, "systematic", "")) : ""
    nom = t isa AbstractDict ? String(get(t, "nominal", "")) : ""
    up = t isa AbstractDict ? String(get(t, "up", "")) : ""
    down = t isa AbstractDict ? String(get(t, "down", "")) : ""
    if isempty(syst)
        (isempty(nom) && isempty(up) && isempty(down)) ||
            push!(errs, "$label: nominal/up/down keys need a 'systematic' input")
    else
        isempty(nom) && push!(errs, "$label: 'nominal' key required with systematic = '$syst'")
        isempty(up) == isempty(down) || push!(errs, "$label: give both 'up' and 'down' or neither")
        haskey(inputs, syst) && push!(errs, "$label: systematic input '$syst' must not be in inputs")
    end
    return name, set, corr, inputs, syst, (nom, up, down)
end
