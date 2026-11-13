"""
    ShapeVariationConfig

One `[[shape_variations]]` table: an object-kinematics (shape) systematic
variation of MC samples. The collection `collection` is re-derived for the
directions up and down, object selection, event selection and histogram values
are recomputed, and the histograms are stored as `<name>Up` / `<name>Down`.

- `name`: nuisance name (`[A-Za-z0-9_]+`).
- `collection`: NanoAOD collection prefix (e.g. `Jet`).
- `kind`: `:jes`, `:jer` or `:scale`.
- `fields`: collection fields multiplied by the per-object factor
  (default `["pt", "mass"]`; fields the selection does not read are skipped).
- `samples`: MC samples the variation applies to (empty = all MC samples).
- `met`: MET prefix (e.g. `PuppiMET`) whose `_pt`/`_phi` are recomputed by
  propagating the change of the object pt (`""` = no propagation);
  `met_min_pt`: minimum unvaried object pt entering the propagation.
- `params`: kind-specific settings with defaults filled in and paths resolved
  (see `shape_variations`).
"""
struct ShapeVariationConfig
    name::String
    collection::String
    kind::Symbol
    fields::Vector{String}
    samples::Vector{String}
    met::String
    met_min_pt::Float64
    params::Dict{String,Any}
end
