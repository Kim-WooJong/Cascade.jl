"""
    read_store(path) -> HistogramStore

Read a store written by `write_store`.
"""
read_store(path::AbstractString) = _store_from_json(JSON3.read(read(path, String)), path)

function _store_from_json(j, path)
    get(j, :format, "") == "cascade-histograms" || throw(ArgumentError("$path is not a Cascade histogram store"))
    s = HistogramStore(Dict{HistKey,BinnedHist}(), _todict(j[:meta]))
    for e in j[:hists]
        s.hists[HistKey(String(e[:region]), String(e[:sample]), String(e[:variation]), String(e[:variable]))] =
            BinnedHist(Float64.(e[:edges]), Float64.(e[:sumw]), Float64.(e[:sumw2]))
    end
    return s
end

_todict(x::JSON3.Object) = Dict{String,Any}(String(k) => _todict(v) for (k, v) in pairs(x))
_todict(x::JSON3.Array) = Any[_todict(v) for v in x]
_todict(x) = x
