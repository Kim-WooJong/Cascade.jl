"""
    lumimask_column(m::LumiMask, runs::AbstractVector, lumis::AbstractVector) -> Vector{Bool}

Evaluate `in_lumimask` for every event.
"""
function lumimask_column(m::LumiMask, runs::AbstractVector, lumis::AbstractVector)
    length(runs) == length(lumis) || throw(DimensionMismatch("run/lumi length mismatch"))
    out = Vector{Bool}(undef, length(runs))
    @inbounds for i in eachindex(runs)
        out[i] = in_lumimask(m, runs[i], lumis[i])
    end
    return out
end
