# Reading the per-chunk select/correct artifacts of a workdir (real-data tests, oracle tools).
using JSON3

"""
    sf_chunk_rows(work, sample) -> Vector{NamedTuple}

One entry per chunk of `sample`: source `path`, event-table `entries`,
`stage`, region stages and the weight columns of the correct step.
"""
function sf_chunk_rows(work::AbstractString, sample::AbstractString)
    skim = JSON3.read(read(joinpath(work, "skim", sample * ".json"), String))
    out = NamedTuple[]
    for e in skim[:files]
        chunk = String(e[:chunk])
        t = read_event_table(joinpath(work, "select", sample, chunk * ".cols"))
        w, _, order = read_column_file(joinpath(work, "correct", sample, chunk * ".cols"))
        push!(out, (path = String(e[:path]), entries = Vector{Int}(t["entry"]), stage = t["stage"],
                    region_stage = t.meta["region_stage"], weights = w, labels = order))
    end
    return out
end
