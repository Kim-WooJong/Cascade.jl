const ONE_SIGMA_CL = 0.6826894921370859

"""
    poisson_errors(counts; cl=0.6826894921370859) -> (low, high)

Frequentist (Garwood) central Poisson intervals for observed integer `counts`,
returned as non-negative error magnitudes `n - λ_low` and `λ_high - n`. With
`α = 1 - cl`: `λ_low` solves `P(X >= n | λ) = α/2` (`λ_low = 0` for `n = 0`) and
`λ_high` solves `P(X <= n | λ) = α/2`; i.e. `λ_low = χ²_{α/2}(2n)/2` and
`λ_high = χ²_{1-α/2}(2n+2)/2`. Non-integer or negative counts are rejected.
"""
function poisson_errors(counts::AbstractVector{<:Real}; cl::Real=ONE_SIGMA_CL)
    0 < cl < 1 || throw(ArgumentError("cl must be in (0, 1)"))
    alpha = 1 - Float64(cl)
    low, high = zeros(length(counts)), zeros(length(counts))
    for (i, c) in enumerate(counts)
        c >= 0 && isinteger(c) || throw(ArgumentError("Poisson intervals need non-negative integer counts (bin $i: $c)"))
        n = Int(c)
        lo = n == 0 ? 0.0 : solve_gamma_p(n, alpha / 2, 0.0, Float64(n))
        hi = solve_gamma_p(n + 1, 1 - alpha / 2, Float64(n), n + 20 * sqrt(n + 1.0) + 20)
        low[i], high[i] = n - lo, hi - n
    end
    return (low, high)
end

"""Bisection for `x` in `[a, b]` with `gamma_p(k, x) = p` (`gamma_p` increases in `x`)."""
function solve_gamma_p(k::Int, p::Float64, a::Float64, b::Float64)
    for _ in 1:200
        m = (a + b) / 2
        gamma_p(k, m) < p ? (a = m) : (b = m)
        b - a <= 1e-13 * max(1.0, b) && break
    end
    return (a + b) / 2
end

"""Regularized lower incomplete gamma function `P(k, x)` for integer `k >= 1`."""
function gamma_p(k::Int, x::Float64)
    x <= 0 && return 0.0
    a = Float64(k)
    prefactor = exp(-x + a * log(x) - log_factorial(k - 1))
    if x < a + 1
        term = 1 / a
        s = term
        for j in 1:100_000
            term *= x / (a + j)
            s += term
            abs(term) < abs(s) * 1e-16 && break
        end
        return min(1.0, s * prefactor)
    end
    # Continued fraction for Q(k, x) (modified Lentz).
    tiny = 1e-300
    b = x + 1 - a
    c = 1 / tiny
    d = 1 / b
    h = d
    for i in 1:100_000
        an = -i * (i - a)
        b += 2
        d = an * d + b
        abs(d) < tiny && (d = tiny)
        c = b + an / c
        abs(c) < tiny && (c = tiny)
        d = 1 / d
        del = d * c
        h *= del
        abs(del - 1) < 1e-16 && break
    end
    return max(0.0, 1 - prefactor * h)
end

"""`log(n!)`: exact sum for small `n`, Stirling series otherwise."""
function log_factorial(n::Int)
    n < 0 && throw(ArgumentError("negative factorial"))
    n <= 64 && return sum(log, 1:n; init=0.0)
    m = Float64(n)
    return m * log(m) - m + 0.5 * log(2pi * m) + 1 / (12m) - 1 / (360m^3) + 1 / (1260m^5)
end
