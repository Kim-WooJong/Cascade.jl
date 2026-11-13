"""
    SampleTemplates(name, nominal::BinnedHist, variations=Dict{String,BinnedHist}())

Histograms of one sample (or of a group of samples) for one variable: the
nominal histogram and any number of named variation histograms, all with the
nominal's bin edges. Variation names follow the fit's nuisance names, by default
`"<nuisance>Up"` / `"<nuisance>Down"` (see [`infer_nuisances`](@ref)).
"""
struct SampleTemplates
    name::String
    nominal::BinnedHist
    variations::Dict{String,BinnedHist}

    function SampleTemplates(name::AbstractString, nominal::BinnedHist,
                             variations::AbstractDict=Dict{String,BinnedHist}())
        isempty(name) && throw(ArgumentError("empty sample name"))
        vs = Dict{String,BinnedHist}()
        for (k, h) in variations
            h isa BinnedHist || throw(ArgumentError("variation $k of $name is not a BinnedHist"))
            h.edges == nominal.edges ||
                throw(ArgumentError("variation $k of $name has bin edges different from the nominal"))
            vs[String(k)] = h
        end
        return new(String(name), nominal, vs)
    end
end
