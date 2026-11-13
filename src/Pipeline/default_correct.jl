"""
    default_correct(ctx::CorrectionContext) -> Dict{String,Vector{Float64}}

Built-in `:correct` hook: nominal = base weight of the selection; each
expression variation `w:<name>Up/Down` of the table gives weight x factor.
"""
function default_correct(ctx::CorrectionContext)
    t = ctx.table
    w = Vector{Float64}(t["weight"])
    out = Dict{String,Vector{Float64}}(Histograms.NOMINAL => w)
    for name in t.order
        startswith(name, "w:") || continue
        out[name[3:end]] = w .* t[name]
    end
    return out
end
