"""
    load_ttbar_cutflow(dir, cfg) -> Cutflow

Raw (unnormalised) MC cutflow of every sample in `cfg["xsec_pb"]` from
`<dir>/<sample>.tsv`; `sumw2` is not recorded in those files and is left zero.
"""
function load_ttbar_cutflow(dir::AbstractString, cfg::AbstractDict)
    stages = nothing
    sumw = Dict{String,Vector{Float64}}()
    for sample in sort(collect(keys(cfg["xsec_pb"])))
        _, s, w, _ = read_ttbar_cutflow(joinpath(dir, sample * ".tsv"))
        stages === nothing && (stages = s)
        s == stages || error("cutflow stages of $sample differ")
        sumw[sample] = w
    end
    return Cutflow(stages, sumw)
end
