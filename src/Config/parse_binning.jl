"""
    parse_binning(spec::AbstractDict) -> Vector{Float64}

Bin edges from a histogram table. Exactly one of:
- `edges = [e0, e1, ...]` explicit edges;
- `range = [start, step, stop]` -> `collect(start:step:stop)`;
- `linspace = [low, high, nbins]` -> `collect(range(low, high; length = nbins + 1))`.
The constructions are the Julia ones so that edges are bit-identical to code
that used the same expressions.
"""
function parse_binning(spec::AbstractDict)
    keys_present = [k for k in ("edges", "range", "linspace") if haskey(spec, k)]
    length(keys_present) == 1 ||
        throw(ArgumentError("histogram needs exactly one of edges/range/linspace, got $(keys_present)"))
    k = only(keys_present)
    v = spec[k]
    edges = if k == "edges"
        Float64.(v)
    elseif k == "range"
        length(v) == 3 || throw(ArgumentError("range must be [start, step, stop]"))
        collect(Float64(v[1]):Float64(v[2]):Float64(v[3]))
    else
        length(v) == 3 || throw(ArgumentError("linspace must be [low, high, nbins]"))
        collect(range(Float64(v[1]), Float64(v[2]); length = Int(v[3]) + 1))
    end
    length(edges) >= 2 || throw(ArgumentError("histogram needs at least one bin"))
    issorted(edges; lt = <=) || throw(ArgumentError("bin edges must be strictly increasing"))
    return edges
end
