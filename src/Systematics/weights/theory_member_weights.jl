"""
    theory_member_weights(cfg, sample, source_path, table, weights)

Copy weight columns and add internal member weights on corrected nominal.
Theory/scalar/shape nuisance cross-products are deliberately not generated.
"""
function theory_member_weights(cfg, sample, path, table, weights; source = nothing)
    ts=[t for t in theory_weights(cfg) if sample.name in t["samples"]]
    isempty(ts) && return weights
    out=Dict{String,Vector{Float64}}(k=>Vector{Float64}(v) for (k,v) in weights)
    r=BranchReader(sample.format,path,Int.(table["entry"]);options=get(sample.raw,"source",Dict()),source)
    try
        for t in ts
            fs=vector_members(r,t)
            for (j,k) in enumerate(t["indices"])
                label="__theory_$(t["name"])_$k"
                haskey(out,label) && throw(ArgumentError("theory member label collision: $label"))
                v=out["nominal"] .* fs[j]
                all(x->isfinite(x)&&isfinite(x*x),v) || throw(ArgumentError("theory '$(t["name"])' produced nonfinite weights in $path"))
                out[label]=v
            end
        end
    finally
        close(r)
    end
    return out
end
