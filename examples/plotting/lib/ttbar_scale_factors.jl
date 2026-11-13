"""
    ttbar_scale_factors(dir, cfg) -> Dict{String,Float64}

`σ L / Σw_gen` per simulated sample: σ = value × br from `cfg["xsec_pb"]`, L =
`cfg["lumi_pb"]`, Σw_gen = the `gen_sumw` header entry of `<dir>/<sample>.tsv`
(histogram and cutflow TSVs both carry it).
"""
function ttbar_scale_factors(dir::AbstractString, cfg::AbstractDict)
    out = Dict{String,Float64}()
    for (sample, x) in cfg["xsec_pb"]
        header = Dict(String(a) => String(b) for (a, b) in
                      (split(kv, "="; limit=2) for kv in split(readline(joinpath(dir, sample * ".tsv")))[2:end]))
        sigma = Float64(x["value"]) * Float64(x["br"])
        out[sample] = sigma * Float64(cfg["lumi_pb"]) / parse(Float64, header["gen_sumw"])
    end
    return out
end
