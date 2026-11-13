# Standard normal helpers (private).
_normal_cdf(x::Real) = 0.5 * erfc(-x / sqrt(2))
_normal_sf(x::Real) = 0.5 * erfc(x / sqrt(2))
