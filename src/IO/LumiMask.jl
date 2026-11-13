"""
    LumiMask

Data-quality mask: run range `[run_min, run_max]` and, if `use_golden`, the
certified luminosity-section ranges per run (inclusive).
"""
struct LumiMask
    run_min::Int
    run_max::Int
    ranges::Dict{Int,Vector{Tuple{Int,Int}}}
    use_golden::Bool
end

LumiMask(run_min::Integer, run_max::Integer) = LumiMask(run_min, run_max, Dict{Int,Vector{Tuple{Int,Int}}}(), false)

"""
    in_lumimask(m::LumiMask, run, lumi) -> Bool

True if the run is inside the run range and (if a Golden JSON is used) the
luminosity section is certified.
"""
function in_lumimask(m::LumiMask, run::Integer, lumi::Integer)
    m.run_min <= run <= m.run_max || return false
    m.use_golden || return true
    for (a, b) in get(m.ranges, Int(run), _NO_RANGES)
        a <= lumi <= b && return true
    end
    return false
end

const _NO_RANGES = Tuple{Int,Int}[]
