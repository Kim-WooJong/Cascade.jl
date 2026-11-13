"""
    counting_estimate(model, channel; signal) -> NamedTuple

Simple counting estimate of the signal strength in `channel` from the integrated
yields at the initial parameters: `mu = (N - B) / S` with `N` the observed
count, `S` the summed yield of the `signal` samples and `B` the rest, and its
data-statistical error `sqrt(N) / S`. A cross-check, not a fit.
"""
function counting_estimate(model::HistModel, channel::AbstractString; signal)
    ci = findfirst(==(channel), model.channels)
    ci === nothing && throw(ArgumentError("unknown channel $channel"))
    isempty(model.observations) && throw(ArgumentError("model has no observations"))
    ys = expected_yields(model, [p.init for p in model.parameters])
    s = b = 0.0
    for (k, t) in enumerate(model.samples)
        t.channel == ci || continue
        t.name in signal ? (s += sum(ys[k])) : (b += sum(ys[k]))
    end
    n = sum(model.observations[model.channel_bins[ci]])
    return (channel = String(channel), data = n, signal = s, background = b, mu = (n - b) / s,
            mu_stat_error = sqrt(n) / s)
end
