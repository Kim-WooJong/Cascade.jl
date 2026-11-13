"""
    load_lumimask(golden_json; run_min = typemin(Int), run_max = typemax(Int)) -> LumiMask

Read a CMS certification JSON (`{"run": [[first, last], ...], ...}`). An empty
path gives a run-range-only mask.
"""
function load_lumimask(path::AbstractString; run_min::Integer = typemin(Int), run_max::Integer = typemax(Int))
    isempty(path) && return LumiMask(run_min, run_max)
    j = JSON3.read(read(path, String))
    ranges = Dict{Int,Vector{Tuple{Int,Int}}}()
    for (run, lst) in pairs(j)
        ranges[parse(Int, String(run))] = [(Int(p[1]), Int(p[2])) for p in lst]
    end
    return LumiMask(run_min, run_max, ranges, true)
end
