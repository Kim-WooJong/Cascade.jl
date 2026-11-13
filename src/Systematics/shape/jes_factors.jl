"""
    jes_factors(k::JESShape, collection, cols, needed) -> (up, down)

Per-object factors `1 + u` and `1 - u` with `u = uncertainty(eta, pt)` for every
object of `collection` in events with `needed[i]` (others: 1.0).
"""
function jes_factors(k::JESShape, collection::AbstractString, cols::AbstractDict, needed)
    pt = cols[collection * "_pt"]; eta = cols[collection * "_eta"]
    up = ones(length(pt.content)); down = ones(length(pt.content))
    _jes_loop!(up, down, k.uncertainty, pt.content, eta.content, pt.offsets, needed)
    return up, down
end

function _jes_loop!(up, down, c, pt, eta, offsets, needed)
    for i in 1:length(offsets)-1
        (needed === nothing || needed[i]) || continue
        for j in offsets[i]+1:offsets[i+1]
            u = evaluate(c, Float64(eta[j]), Float64(pt[j]))
            up[j] = 1.0 + u
            down[j] = 1.0 - u
        end
    end
    return nothing
end
