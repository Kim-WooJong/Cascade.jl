"""
    trigger_or_ratio(data, mc; label = "trigger_or") -> Float64

Compute `[1 - prod(1 - data)] / [1 - prod(1 - mc)]` for independent
per-object probabilities of one single-object trigger path. Inputs must have
equal length and contain finite probabilities in `[0,1]`. A zero MC event
efficiency (including no eligible objects) is undefined and throws, never
silently returns unity. A stable recurrence preserves tiny probabilities.
"""
function trigger_or_ratio(data::AbstractVector, mc::AbstractVector; label::AbstractString = "trigger_or")
    length(data) == length(mc) || throw(ArgumentError("$label: data/MC leg counts differ"))
    ed = 0.0
    em = 0.0
    for (d, m) in zip(data, mc)
        for (kind, x) in (("data", d), ("mc", m))
            x isa Real && !(x isa Bool) && isfinite(x) && 0 <= x <= 1 ||
                throw(ArgumentError("$label: $kind efficiency must be finite and in [0,1], got $(repr(x))"))
        end
        ed += (1 - ed) * Float64(d)
        em += (1 - em) * Float64(m)
    end
    em > 0 || throw(ArgumentError("$label: zero MC event trigger efficiency; event SF is undefined"))
    sf = ed / em
    isfinite(sf) || throw(ArgumentError("$label: non-finite event trigger SF"))
    return sf
end
