"""
    flat_factors(t::FlatWeight, n) -> WeightFactors

Constant factors of a `FlatWeight` for `n` rows.
"""
flat_factors(t::FlatWeight, n::Integer) =
    WeightFactors(t.name, fill(t.nominal, n), fill(t.up, n), fill(t.down, n))
