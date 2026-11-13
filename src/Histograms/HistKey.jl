"""
    HistKey(region, sample, variation, variable)

Index of one histogram in a `HistogramStore`.
"""
struct HistKey
    region::String
    sample::String
    variation::String
    variable::String
end

Base.:(==)(a::HistKey, b::HistKey) =
    a.region == b.region && a.sample == b.sample && a.variation == b.variation && a.variable == b.variable
Base.hash(k::HistKey, h::UInt) = hash(k.variable, hash(k.variation, hash(k.sample, hash(k.region, hash(:HistKey, h)))))
Base.isless(a::HistKey, b::HistKey) =
    isless((a.region, a.sample, a.variation, a.variable), (b.region, b.sample, b.variation, b.variable))
