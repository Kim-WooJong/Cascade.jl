"""
    shape_variations_for(configs, sample::SampleConfig) -> Vector{ShapeVariationConfig}

Shape variations applying to `sample`: none for data; for MC those whose
`samples` list is empty or contains the sample.
"""
shape_variations_for(configs::AbstractVector{ShapeVariationConfig}, sample::SampleConfig) =
    is_mc(sample) ? [v for v in configs if isempty(v.samples) || sample.name in v.samples] : ShapeVariationConfig[]
