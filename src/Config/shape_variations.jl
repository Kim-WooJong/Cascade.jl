const SHAPE_KIND_DEFAULTS = Dict{Symbol,Dict{String,Any}}(
    :jes => Dict{String,Any}("corrections" => "", "source" => "", "inputs" => Dict{String,Any}()),
    :jer => Dict{String,Any}("corrections" => "", "resolution" => "", "scale_factor" => "",
                             "smear_file" => "", "smear" => "JERSmear", "rho" => "Rho_fixedGridRhoFastjetAll",
                             "event" => "event", "genjet" => "GenJet", "genjet_index" => "genJetIdx",
                             "match_dr" => 0.2, "match_nsigma" => 3.0, "nominal" => false, "inputs" => Dict{String,Any}()),
    :scale => Dict{String,Any}("up" => "", "down" => ""))

const SHAPE_PATH_PARAMS = ("corrections", "smear_file")

"""
    shape_variations(cfg::AnalysisConfig) -> Vector{ShapeVariationConfig}

Parse the `[[shape_variations]]` tables of the analysis (empty if absent), in
file order. Common keys: `name`, `collection`, `kind`, `fields`, `samples`,
`met`, `met_min_pt` (see `ShapeVariationConfig`). Kind-specific keys:

- `kind = "jes"`: `corrections` (correction-set file), `source` (name of the
  uncertainty correction with inputs `(JetEta, JetPt)`, e.g.
  `Summer22_22Sep2023_V2_MC_Total_AK4PFPuppi`); factor `1 +/- unc`.
- `kind = "jer"`: `corrections`, `resolution` (inputs `JetEta, JetPt, Rho`),
  `scale_factor` (inputs `JetEta[, JetPt], systematic`), `smear_file` and
  `smear` (correctionlib `JERSmear`), `rho`, `event` (event-id column),
  `genjet`, `genjet_index`, `match_dr` (0.2), `match_nsigma` (3.0) and
  `nominal` (false): if true the nominal MC collection is smeared too.
- `kind = "scale"`: `up`, `down`: object expressions (fields of the
  collection) giving the multiplicative factors.

Relative correction paths are resolved against the analysis directory after
`\${name}` substitution from `[paths]`.
"""
function shape_variations(cfg::AnalysisConfig)
    raw = cfg.raw
    paths = Dict{String,Any}(get(raw, "paths", Dict{String,Any}()))
    resolve(p) = (q = substitute_paths(p, paths); isabspath(q) ? q : normpath(joinpath(cfg.dir, q)))
    out = ShapeVariationConfig[]
    for t in get(raw, "shape_variations", Any[])
        t isa AbstractDict || throw(ArgumentError("shape_variations entries must be tables"))
        haskey(t, "name") || throw(ArgumentError("shape_variations entry without name"))
        name = String(t["name"])
        kind = Symbol(get(t, "kind", ""))
        haskey(SHAPE_KIND_DEFAULTS, kind) ||
            throw(ArgumentError("shape variation $name: kind must be jes, jer or scale (got '$kind')"))
        common = Set(["name", "collection", "kind", "fields", "samples", "met", "met_min_pt"])
        params = copy(SHAPE_KIND_DEFAULTS[kind])
        for (k, v) in t
            k in common && continue
            haskey(params, k) || throw(ArgumentError("shape variation $name: unknown key '$k' for kind $kind"))
            params[k] = v isa AbstractString ? String(v) : v
        end
        for k in SHAPE_PATH_PARAMS
            haskey(params, k) && !isempty(params[k]) && (params[k] = resolve(params[k]))
        end
        push!(out, ShapeVariationConfig(name, String(get(t, "collection", "")), kind,
                                        String.(get(t, "fields", ["pt", "mass"])),
                                        String.(get(t, "samples", String[])), String(get(t, "met", "")),
                                        Float64(get(t, "met_min_pt", 15.0)), params))
    end
    return out
end
