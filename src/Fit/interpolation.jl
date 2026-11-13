# Interpolation of systematic variations, following the pyhf/HistFactory codes.
# Additive (histosys): code0 (piecewise linear), code4p (polynomial inside |alpha|<1).
# Multiplicative (normsys): code1 (exponential), code4 (polynomial inside |alpha|<1).

"""
    histosys_delta(code, alpha, nom, up, dn)

Additive shift of one bin for nuisance value `alpha` given the nominal and
the +1/-1 sigma templates. `code` is `:code0` or `:code4p` (pyhf default).
"""
function histosys_delta(code::Symbol, alpha, nom::Real, up::Real, dn::Real)
    du = up - nom
    dd = nom - dn
    if code === :code0
        return alpha >= 0 ? alpha * du : alpha * dd
    elseif code === :code4p
        alpha > 1 && return alpha * du
        alpha < -1 && return alpha * dd
        S = 0.5 * (du + dd)
        A = 0.0625 * (du - dd)
        a2 = alpha * alpha
        return alpha * S + A * (a2 * (a2 * (3 * a2 - 10) + 15))
    end
    throw(ArgumentError("unknown histosys interpolation code $code"))
end

"""
    normsys_factor(code, alpha, hi, lo, coeffs)

Multiplicative factor for nuisance value `alpha`. `code` is `:code1` or
`:code4` (pyhf default); `coeffs` come from [`code4_coefficients`](@ref).
"""
function normsys_factor(code::Symbol, alpha, hi::Real, lo::Real, coeffs::NTuple{6,Float64})
    if code === :code1 || alpha >= 1 || alpha <= -1
        code === :code1 || code === :code4 ||
            throw(ArgumentError("unknown normsys interpolation code $code"))
        return alpha >= 0 ? exp(alpha * log(hi)) : exp(-alpha * log(lo))
    end
    code === :code4 || throw(ArgumentError("unknown normsys interpolation code $code"))
    a = alpha
    p = a * (coeffs[1] + a * (coeffs[2] + a * (coeffs[3] + a * (coeffs[4] + a * (coeffs[5] + a * coeffs[6])))))
    return 1 + p
end

"""
    code4_coefficients(hi, lo)

Coefficients a1..a6 of the polynomial `1 + sum(a_i alpha^i)` that matches
`hi^alpha` / `lo^-alpha` in value, first and second derivative at alpha = +-1.
"""
function code4_coefficients(hi::Real, lo::Real)
    (hi > 0 && lo > 0) || throw(ArgumentError("normsys factors must be positive (hi=$hi, lo=$lo)"))
    lh, ll = log(hi), log(lo)
    M = zeros(6, 6)
    for i in 1:6
        M[1, i] = 1.0
        M[2, i] = (-1.0)^i
        M[3, i] = i
        M[4, i] = i * (-1.0)^(i - 1)
        M[5, i] = i * (i - 1)
        M[6, i] = i * (i - 1) * (-1.0)^(i - 2)
    end
    b = [hi - 1, lo - 1, hi * lh, -lo * ll, hi * lh^2, lo * ll^2]
    c = M \ b
    return (c[1], c[2], c[3], c[4], c[5], c[6])
end
