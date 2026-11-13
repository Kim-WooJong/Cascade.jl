"""
    ObjectConfig

Definition of a selected physics-object collection.

- `name`: name used in event expressions (e.g. `electrons`).
- `collection`: NanoAOD collection prefix (e.g. `Electron` -> `Electron_pt`).
- `cut`: per-object expression over the collection fields (`pt > 35.0 && ...`).
- `clean_against`: names of previously defined objects; an object is kept only
  if `deltaR(self, other) > clean_dr` for every selected object in each of them.
- `sort_by`: field to sort the selected objects by (descending), or `""` to
  keep the input order.
"""
struct ObjectConfig
    name::String
    collection::String
    cut::String
    clean_against::Vector{String}
    clean_dr::Float64
    sort_by::String
end
