"""
    luminosity_scale(xsec_pb, branching_ratio, lumi_pb, gen_weight_sum) -> Float64

MC normalisation factor `(xsec_pb * branching_ratio) * lumi_pb / gen_weight_sum`
(operation order fixed for bit-reproducibility).
"""
function luminosity_scale(xsec_pb::Real, branching_ratio::Real, lumi_pb::Real, gen_weight_sum::Real)
    gen_weight_sum == 0 && throw(ArgumentError("gen_weight_sum is zero"))
    sigma = Float64(xsec_pb) * Float64(branching_ratio)
    return sigma * Float64(lumi_pb) / Float64(gen_weight_sum)
end
