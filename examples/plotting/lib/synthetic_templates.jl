"""
    synthetic_templates() -> Dict{String,SampleTemplates}

Deterministic synthetic templates of one mass-like variable (15 bins, 0-300,
with overflow, folded into the last bin by `collect_templates`) given through the plain-array contract
`(sample, variation) => (; edges, sumw, sumw2, overflow)`: four simulated
samples (one with a negative bin from signed weights) with shape variations
(jes, lumi, a 4-point QCD-scale set, 3 PDF eigenvectors, a one-sided top-pT
variation) and integer pseudo-data. Synthetic numbers, not a measurement.
"""
function synthetic_templates()
    edges = collect(0.0:20.0:300.0)
    centers = [(edges[1:end-1] .+ edges[2:end]) ./ 2; 330.0]     # last entry: overflow
    shapes = Dict(
        "ttbar" => (x -> 900 * exp(-x / 70), 0.05),
        "singletop" => (x -> 90 * exp(-x / 60), 0.04),
        "dy" => (x -> 260 * exp(-0.5 * ((x - 90) / 15)^2) + 8 * exp(-x / 100), 0.2),
        "fakes" => (x -> 6 * cos(x / 40), 0.5))
    tilt(k) = x -> 1 + k * (x - 150) / 150
    variations = Dict(
        "jesUp" => tilt(0.08), "jesDown" => tilt(-0.07),
        "lumiUp" => x -> 1.014, "lumiDown" => x -> 0.986,
        "scale_muR0p5" => tilt(0.04), "scale_muR2" => tilt(-0.03), "scale_muF0p5" => x -> 1.03, "scale_muF2" => x -> 0.97,
        "pdf_1" => x -> 1.01, "pdf_2" => tilt(0.015), "pdf_3" => tilt(-0.01),
        "topptUp" => x -> 1 - 0.1 * x / 300)
    affects = Dict("ttbar" => keys(variations), "singletop" => ["jesUp", "jesDown", "lumiUp", "lumiDown"],
                   "dy" => ["jesUp", "jesDown", "lumiUp", "lumiDown"], "fakes" => String[])
    entries = Dict{Tuple{String,String},Any}()
    total = zeros(length(centers))
    hist(y, w) = (; edges, sumw=y[1:end-1], sumw2=abs.(y[1:end-1]) .* w, overflow=(y[end], abs(y[end]) * w))
    for (sample, (shape, w)) in shapes
        y = shape.(centers)
        total .+= y
        entries[(sample, "nominal")] = hist(y, w)
        for v in affects[sample]
            entries[(sample, v)] = hist(y .* variations[v].(centers), w)
        end
    end
    pseudo = round.(total .* (1 .+ 0.04 .* sin.(1.3 .* eachindex(total))))
    entries[("pseudodata", "nominal")] = hist(pseudo, 1.0)
    return collect_templates(entries)
end
