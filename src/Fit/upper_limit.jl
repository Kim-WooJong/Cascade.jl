"""
    upper_limit(model, data; level=0.05, test_stat=:qtilde, bracket=nothing,
                rtol=1e-6, fixed=(), bounds=()) -> NamedTuple

Asymptotic CLs upper limit on the POI at confidence level `1 - level`.
The roots of `CLs(mu) = level` (observed and each expected band) are found
with Brent's method inside `bracket` (default: POI bounds; the upper end is
doubled until all CLs values fall below `level`, as in pyhf).

Returns `(observed, expected)` with `expected` the -2,-1,0,+1,+2 sigma limits.
"""
function upper_limit(model::HistModel, data::Dataset; level::Real=0.05, test_stat::Symbol=:qtilde,
                     bracket=nothing, rtol::Real=1e-6, fixed=(), bounds=())
    s = _asymptotic_setup(model, data, test_stat, fixed, bounds)
    p = model.parameters[_poi_index(model)]
    lo, hi = bracket === nothing ? (max(p.lower, 0.0), p.upper) : (Float64(bracket[1]), Float64(bracket[2]))
    # Expected bands need only the Asimov statistic; cache both statistics separately.
    qa_cache = Dict{Float64,Float64}()
    qo_cache = Dict{Float64,Float64}()
    qA = mu -> get!(() -> _qA(s, mu), qa_cache, Float64(mu))
    qobs = mu -> get!(() -> _teststat(model, s.data, mu, s.kind; fixed=s.fixed, bounds=s.bounds,
                                      free=s.free_data).value, qo_cache, Float64(mu))
    cls_obs = mu -> _cls_from(s.kind, qobs(mu), qA(mu))
    cls_exp = (mu, k) -> _expected_cls(sqrt(qA(mu)))[k]
    vals = mu -> (cls_obs(mu), _expected_cls(sqrt(qA(mu)))...)
    any(v -> v < level, vals(lo)) && throw(ArgumentError("CLs below level at lower bracket $lo"))
    ndouble = 0
    while any(v -> v > level, vals(hi))
        ndouble += 1
        ndouble > 20 && throw(ArgumentError("could not bracket the upper limit"))
        hi *= 2
    end
    obs = _brent(mu -> cls_obs(mu) - level, lo, hi; rtol=rtol)
    exp = [_brent(mu -> cls_exp(mu, k) - level, lo, hi; rtol=rtol) for k in 1:5]
    return (observed=obs, expected=exp)
end

# Brent's root finder on a bracketing interval [a, b].
function _brent(f, a::Float64, b::Float64; rtol::Real=1e-6, atol::Real=1e-12, maxiter::Int=200)
    fa, fb = f(a), f(b)
    fa == 0 && return a
    fb == 0 && return b
    sign(fa) == sign(fb) && throw(ArgumentError("root not bracketed in [$a, $b]"))
    c, fc = a, fa
    d = e = b - a
    for _ in 1:maxiter
        if sign(fb) == sign(fc)
            c, fc = a, fa
            d = e = b - a
        end
        if abs(fc) < abs(fb)
            a, b, c = b, c, b
            fa, fb, fc = fb, fc, fb
        end
        tol = 2 * eps(Float64) * abs(b) + 0.5 * max(atol, rtol * abs(b))
        m = 0.5 * (c - b)
        (abs(m) <= tol || fb == 0) && return b
        if abs(e) >= tol && abs(fa) > abs(fb)
            s = fb / fa
            if a == c
                pp = 2 * m * s
                q = 1 - s
            else
                q = fa / fc
                r = fb / fc
                pp = s * (2 * m * q * (q - r) - (b - a) * (r - 1))
                q = (q - 1) * (r - 1) * (s - 1)
            end
            pp > 0 ? (q = -q) : (pp = -pp)
            if 2 * pp < min(3 * m * q - abs(tol * q), abs(e * q))
                e, d = d, pp / q
            else
                d = m
                e = m
            end
        else
            d = m
            e = m
        end
        a, fa = b, fb
        b += abs(d) > tol ? d : (m > 0 ? tol : -tol)
        fb = f(b)
    end
    return b
end
