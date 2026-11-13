# Artifact layout under the workdir (see docs/DESIGN.md, "Artifacts, keys and caching").
skim_path(workdir, sample) = joinpath(workdir, "skim", string(sample, ".json"))
chunk_path(workdir, step::Symbol, sample, id, ext) = joinpath(workdir, String(step), sample, string(id, ext))
# Chunk artifact of a shape variation: <step>/<sample>/<chunk>.<label><ext>.
shape_chunk_path(workdir, step::Symbol, sample, id, label, ext) =
    joinpath(workdir, String(step), sample, string(id, ".", label, ext))
