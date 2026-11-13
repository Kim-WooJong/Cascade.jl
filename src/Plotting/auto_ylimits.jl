"""
    auto_ylimits(cmp::ROOTPlots.Comparison; logy=false, ymin=nothing, fill=0.6) -> (ymin, ymax)
    auto_ylimits(cumulative, top; logy=false, ymin=nothing, fill=0.6) -> (ymin, ymax)

Upper-pad y range leaving room for the CMS label and the legend: the highest
drawn point (`top`: prediction + band or data + error) ends at the fraction
`fill` of the axis (in log10 for `logy`). The log lower edge is half the
smallest positive stacked value (not below `1e-6 × top`) unless `ymin` is given;
the linear lower edge is 0. `cumulative` holds the per-bin stack sums from the
bottom component upwards.
"""
function auto_ylimits(cmp::Comparison; logy::Bool=false, ymin=nothing, fill::Real=0.6)
    top = max(maximum(cmp.prediction .+ cmp.prediction_errors.high), maximum(cmp.data.sumw .+ cmp.data_errors.high))
    return auto_ylimits([cmp.cumulative; [cmp.data.sumw]], top; logy, ymin, fill)
end

function auto_ylimits(cumulative::AbstractVector, top::Real; logy::Bool=false, ymin=nothing, fill::Real=0.6)
    0 < fill <= 1 || throw(ArgumentError("fill must be in (0, 1]"))
    top > 0 || throw(ArgumentError("nothing positive to draw"))
    if !logy
        lo = ymin === nothing ? 0.0 : Float64(ymin)
        return (lo, lo + (top - lo) / fill)
    end
    positive = filter(x -> isfinite(x) && x > 0, reduce(vcat, cumulative; init=Float64[]))
    lo = ymin !== nothing ? Float64(ymin) : max(minimum(positive; init=top) / 2, 1e-6 * top)
    lo < top || throw(ArgumentError("ymin must lie below the drawn values"))
    return (lo, 10^(log10(lo) + (log10(top) - log10(lo)) / fill))
end
