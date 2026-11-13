# One binning axis (uniform or non-uniform edges) and the bin lookup shared by
# Binning and MultiBinning. Semantics follow correctionlib's find_bin_idx.
const FLOW_VALUE = 0x01
const FLOW_CLAMP = 0x02
const FLOW_ERROR = 0x03
const FLOW_WRAP = 0x04

struct BinAxis
    uniform::Bool
    n::Int                  # number of bins
    low::Float64            # uniform only
    high::Float64           # uniform only
    edges::Vector{Float64}  # non-uniform only
end

nbins(ax::BinAxis) = ax.n

function parse_flow(flow)::UInt8
    if flow isa AbstractString
        flow == "clamp" && return FLOW_CLAMP
        flow == "error" && return FLOW_ERROR
        flow == "wrap" && return FLOW_WRAP
    end
    return FLOW_VALUE
end

function parse_edge(e)::Float64
    isjsonnumber(e) && return Float64(e)
    if e isa AbstractString
        (e == "inf" || e == "+inf") && return Inf
        e == "-inf" && return -Inf
    end
    throw_correction_error("Invalid edge type")
end

function parse_bin_edges(arr::AbstractVector)::Vector{Float64}
    out = Float64[]
    sizehint!(out, length(arr))
    for e in arr
        val = parse_edge(e)
        if !isempty(out) && !(out[end] < val)
            throw_correction_error("binning edges are not monotone increasing")
        end
        push!(out, val)
    end
    return out
end

"""Build a BinAxis from a JSON `edges` value (array or UniformBinning object)."""
function bin_axis(edgesjson, what::String, dim::Int)
    if edgesjson isa AbstractVector
        edges = parse_bin_edges(edgesjson)
        length(edges) >= 2 || throw_correction_error("Inconsistency in $what: fewer than two bin edges")
        return BinAxis(false, length(edges) - 1, edges[1], edges[end], edges)
    elseif isjsonobject(edgesjson)
        n = jint(edgesjson, :n)
        n > 0 || throw_correction_error(what == "Binning" ?
            "Error when processing Binning with UniformBinning: number of bins is zero" :
            "Error when processing MultiBinning: number of bins for dimension $dim is zero")
        low = jnumber(edgesjson, :low)
        high = jnumber(edgesjson, :high)
        return BinAxis(true, n, low, high, Float64[])
    end
    throw_correction_error(what == "Binning" ?
        "Error when processing Binning: edges are neither an array nor a UniformBinning object" :
        "Error when processing MultiBinning: edges for dimension $dim are neither an array nor a UniformBinning object")
end

# First 0-based position p such that value < edges[p+1] (std::upper_bound).
@inline function upper_bound(edges::Vector{Float64}, value::Float64)
    lo = 0
    hi = length(edges)
    @inbounds while lo < hi
        mid = (lo + hi) >>> 1
        if value < edges[mid+1]
            hi = mid
        else
            lo = mid + 1
        end
    end
    return lo
end

@noinline function throw_flow_error(below::Bool, what::String, varidx::Int, value::Float64)
    side = below ? "below" : "above"
    throw(CorrectionError("Index $side bounds in $what for input argument $varidx value: $value"))
end

"""
    find_bin(ax, value, flow, varidx, what) -> Int

0-based bin index. Returns `nbins(ax)` to request the flow default value.
`varidx` (0-based input position) and `what` are used in error messages.
"""
@inline function find_bin(ax::BinAxis, value::Float64, flow::UInt8, varidx::Int, what::String)::Int
    if ax.uniform
        low = ax.low
        high = ax.high
        n = ax.n
        if value < low || value >= high
            flow == FLOW_VALUE && return n
            flow == FLOW_CLAMP && return value < low ? 0 : n - 1
            flow == FLOW_ERROR && throw_flow_error(value < low, what, varidx, value)
        end
        norm = (value - low) / (high - low)
        if flow == FLOW_WRAP
            norm -= floor(norm)
        end
        r = Float64(n) * norm
        (r >= 0.0 && r <= Float64(n)) ||
            throw(CorrectionError("Invalid input value $value for uniform binning in $what for input argument $varidx"))
        return unsafe_trunc(Int, r)
    end
    edges = ax.edges
    len = length(edges)
    if flow == FLOW_WRAP
        lo = @inbounds edges[1]
        hi = @inbounds edges[len]
        norm = (value - lo) / (hi - lo)
        norm -= floor(norm)
        value = lo + norm * (hi - lo)
    end
    pos = upper_bound(edges, value)
    if pos == 0
        flow == FLOW_VALUE && return len - 1
        flow == FLOW_ERROR && throw_flow_error(true, what, varidx, value)
        flow == FLOW_WRAP && throw(CorrectionError("Unexpected underflow with wrap flow in $what"))
        pos = 1
    elseif pos == len
        flow == FLOW_VALUE && return len - 1
        flow == FLOW_ERROR && throw_flow_error(false, what, varidx, value)
        flow == FLOW_WRAP && throw(CorrectionError("Unexpected overflow with wrap flow in $what"))
        pos = len - 1
    end
    return pos - 1
end
