# Evaluation throughput of Cascade.Corrections on oracle points.
using Cascade
using Cascade.Corrections

"""
    measure_throughput(oraclefile; csetpath=nothing, nrows=200_000) -> NamedTuple

For each correction, tile the oracle points that evaluate without error to
`nrows` rows and time vectorized `evaluate!` (best of 3) and a scalar loop.
Returns total rows and seconds for both modes.
"""
function measure_throughput(oraclefile::AbstractString; csetpath = nothing, nrows = 200_000)
    o = Cascade.Corrections.read_json(read(oraclefile))
    cset = load_correctionset(csetpath === nothing ? o["source"] : csetpath)
    tvec = 0.0
    tscalar = 0.0
    total = 0
    for entry in o["corrections"]
        c = entry["compound"] ? compound_corrections(cset)[entry["name"]] : cset[entry["name"]]
        types = entry["input_types"]
        rows = [decode_args(a, types) for (a, e) in zip(entry["args"], entry["errors"])
                if e === nothing && length(a) == length(types)]
        isempty(rows) && continue
        tiled = [rows[mod1(i, length(rows))] for i in 1:nrows]
        cols = ntuple(j -> collect_column([r[j] for r in tiled]), length(types))
        out = Vector{Float64}(undef, nrows)
        evaluate!(out, c, cols...)
        tvec += minimum(@elapsed(evaluate!(out, c, cols...)) for _ in 1:3)
        tscalar += minimum(@elapsed(scalar_loop!(out, c, cols)) for _ in 1:3)
        total += nrows
    end
    return (rows = total, vector_seconds = tvec, scalar_seconds = tscalar)
end

function scalar_loop!(out, c, cols::NTuple{N,Any}) where {N}
    @inbounds for i in eachindex(out)
        out[i] = evaluate(c, map(col -> col[i], cols)...)
    end
    return out
end
