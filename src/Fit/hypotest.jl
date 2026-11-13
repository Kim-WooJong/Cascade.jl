"""
    HypotestResult

Asymptotic CLs hypothesis test at one POI value (see [`hypotest`](@ref)).
`q`/`qA` are the observed and Asimov test statistics; `cls`, `clsb`, `clb`
the observed p-values; `cls_expected` the expected CLs for the
-2,-1,0,+1,+2 sigma bands of the expected limit (pyhf order, increasing CLs).
"""
struct HypotestResult
    mu::Float64
    test_stat::Symbol
    q::Float64
    qA::Float64
    cls::Float64
    clsb::Float64
    clb::Float64
    cls_expected::Vector{Float64}
end

"""
    hypotest(model, data, mu; test_stat=:qtilde, fixed=(), bounds=()) -> HypotestResult

Asymptotic CLs test of POI value `mu` (arXiv:1007.1727), reproducing
pyhf's `AsymptoticCalculator`: the background-only Asimov dataset is built
with nuisance parameters fitted to `data` at POI = 0; `test_stat` is `:qtilde`
or `:q`.
"""
function hypotest(model::HistModel, data::Dataset, mu::Real; test_stat::Symbol=:qtilde,
                  fixed=(), bounds=())
    return _hypotest(_asymptotic_setup(model, data, test_stat, fixed, bounds), mu)
end

struct _AsymptoticSetup
    model::HistModel
    data::Dataset
    kind::Symbol
    fixed::Vector{Any}
    bounds::Vector{Any}
    free_data::FitResult
    asimov::Dataset
    free_asimov::FitResult
end

function _asymptotic_setup(model::HistModel, data::Dataset, kind::Symbol, fixed, bounds)
    kind in (:qtilde, :q) || throw(ArgumentError("test_stat must be :qtilde or :q"))
    fx = collect(Any, fixed)
    b = collect(Any, _stat_bounds(model, kind, bounds))
    free = fit(model, data; fixed=fx, bounds=b, hesse=false)
    asimov = asimov_data(model, 0.0, data; fixed=fx, bounds=b)
    free_a = fit(model, asimov; fixed=fx, bounds=b, hesse=false)
    return _AsymptoticSetup(model, data, kind, fx, b, free, asimov, free_a)
end

function _qA(s::_AsymptoticSetup, mu::Real)
    return _teststat(s.model, s.asimov, mu, s.kind; fixed=s.fixed, bounds=s.bounds,
                     free=s.free_asimov).value
end

function _hypotest(s::_AsymptoticSetup, mu::Real)
    q = _teststat(s.model, s.data, mu, s.kind; fixed=s.fixed, bounds=s.bounds, free=s.free_data).value
    qA = _qA(s, mu)
    cls, clsb, clb = _cls_tail_probs(s.kind, q, qA)
    return HypotestResult(mu, s.kind, q, qA, cls, clsb, clb, _expected_cls(sqrt(qA)))
end

# Observed (CLs, CLs+b, CLb) from q and qA (pyhf AsymptoticCalculator conventions).
function _cls_tail_probs(kind::Symbol, q::Real, qA::Real)
    sq, sqA = sqrt(q), sqrt(qA)
    ts = (kind === :q || sq <= sqA) ? sq - sqA : (q - qA) / (2 * sqA)
    clsb = _normal_sf(ts + sqA)
    clb = _normal_sf(ts)
    return (clsb / clb, clsb, clb)
end

_cls_from(kind::Symbol, q::Real, qA::Real) = _cls_tail_probs(kind, q, qA)[1]

_expected_cls(sqA::Real) = [_normal_sf(n + sqA) / _normal_sf(n) for n in (2, 1, 0, -1, -2)]
