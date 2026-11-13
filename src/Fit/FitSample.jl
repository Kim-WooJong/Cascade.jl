"""
    FitSample(name, members)

One fit process: the histograms of the store samples `members` summed
(e.g. all samples of the configuration group `"ttbar"`).
"""
struct FitSample
    name::String
    members::Vector{String}
end
