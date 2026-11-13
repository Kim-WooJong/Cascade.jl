"""
    synthetic_nuisances() -> Vector{Nuisance}

Nuisance model of [`synthetic_templates`](@ref): up/down pairs, an envelope,
a quadrature group and a one-sided mirrored variation.
"""
synthetic_nuisances() = [
    Nuisance("jes"), Nuisance("lumi"),
    Nuisance("scale", ["scale_muR0p5", "scale_muR2", "scale_muF0p5", "scale_muF2"]; rule=:envelope),
    Nuisance("pdf", ["pdf_1", "pdf_2", "pdf_3"]; rule=:quadrature),
    Nuisance("toppt"; down=nothing)]
