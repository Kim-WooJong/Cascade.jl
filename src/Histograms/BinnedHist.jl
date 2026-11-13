"""
    BinnedHist(edges, sumw, sumw2)
    BinnedHist(edges)

One-dimensional weighted histogram: `sumw[k]` and `sumw2[k]` for bin
`[edges[k], edges[k+1])`. Flow handling is defined by `fill_bin!`.
"""
struct BinnedHist
    edges::Vector{Float64}
    sumw::Vector{Float64}
    sumw2::Vector{Float64}
    function BinnedHist(edges::Vector{Float64}, sumw::Vector{Float64}, sumw2::Vector{Float64})
        (length(edges) >= 2 && length(sumw) == length(edges) - 1 && length(sumw2) == length(sumw)) ||
            throw(ArgumentError("inconsistent histogram arrays"))
        return new(edges, sumw, sumw2)
    end
end

BinnedHist(edges::AbstractVector{<:Real}) =
    BinnedHist(Vector{Float64}(edges), zeros(length(edges) - 1), zeros(length(edges) - 1))

"""
    integral(h::BinnedHist) -> Float64

Sum of bin contents (all bins, flow already folded by `fill_bin!`).
"""
integral(h::BinnedHist) = sum(h.sumw)

Base.:(==)(a::BinnedHist, b::BinnedHist) = a.edges == b.edges && a.sumw == b.sumw && a.sumw2 == b.sumw2
