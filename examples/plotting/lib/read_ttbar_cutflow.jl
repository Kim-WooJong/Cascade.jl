"""
    read_ttbar_cutflow(path) -> (header, stages, sumw, nraw)

Read one cutflow TSV of the prior ttbar control analysis (`stage sumw n_raw` rows).
"""
function read_ttbar_cutflow(path::AbstractString)
    lines = readlines(path)
    header = Dict(String(a) => String(b) for (a, b) in (split(kv, "="; limit=2) for kv in split(lines[1])[2:end]))
    stages, sumw, nraw = String[], Float64[], Int[]
    for line in lines[3:end]
        isempty(strip(line)) && continue
        s, w, n = split(line, '\t')
        push!(stages, s); push!(sumw, parse(Float64, w)); push!(nraw, parse(Int, n))
    end
    return header, stages, sumw, nraw
end
