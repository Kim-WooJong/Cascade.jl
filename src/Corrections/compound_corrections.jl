"""
    compound_corrections(cset::CorrectionSet) -> Dict{String,CompoundCorrection}

Compound corrections of the set, keyed by name.
"""
compound_corrections(cs::CorrectionSet) = cs.compound
