"""
    SampleGroup(label, color, samples)

One stacked process: legend `label` (ROOT TLatex, e.g. `"t#bar{t}"`), fill
`color` as `"#RRGGBB"`, and the sample names summed into it.
"""
struct SampleGroup
    label::String
    color::String
    samples::Vector{String}

    function SampleGroup(label::AbstractString, color::AbstractString, samples::AbstractVector)
        isempty(label) && throw(ArgumentError("empty group label"))
        occursin(r"^#[0-9a-fA-F]{6}$", color) || throw(ArgumentError("group $label: color must be #RRGGBB"))
        isempty(samples) && throw(ArgumentError("group $label has no sample"))
        return new(String(label), String(color), String.(samples))
    end
end
