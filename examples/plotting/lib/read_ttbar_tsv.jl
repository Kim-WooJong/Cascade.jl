"""
    read_ttbar_tsv(path) -> (header::Dict{String,String}, hists::Dict{String,BinnedHist})

Read one histogram TSV of the prior ttbar control analysis: a header line
`# key=value ...`, a column line, then `hist low high sumw sumw2` rows (bins in
order; overflow already folded into the last bin, underflow dropped upstream).
"""
function read_ttbar_tsv(path::AbstractString)
    lines = readlines(path)
    header = Dict(String(a) => String(b) for (a, b) in (split(kv, "="; limit=2) for kv in split(lines[1])[2:end]))
    cols = Dict{String,Tuple{Vector{Float64},Vector{Float64},Vector{Float64}}}()
    for line in lines[3:end]
        isempty(strip(line)) && continue
        name, lo, hi, w, w2 = split(line, '\t')
        e, s, s2 = get!(() -> (Float64[], Float64[], Float64[]), cols, String(name))
        isempty(e) && push!(e, parse(Float64, lo))
        last(e) == parse(Float64, lo) || error("$path: $name bins are not contiguous")
        push!(e, parse(Float64, hi)); push!(s, parse(Float64, w)); push!(s2, parse(Float64, w2))
    end
    return header, Dict(n => binned_hist(e, s, s2) for (n, (e, s, s2)) in cols)
end
