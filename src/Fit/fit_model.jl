"""
    fit(model, data=observed_data(model); init=nothing, fixed=(), bounds=(),
        hesse=true, maxiter=200, tol=1e-12) -> FitResult

Maximum-likelihood fit of `model` to `data` (minimises [`nll`](@ref)) with
the projected Newton minimiser [`newton_minimize`](@ref).

- `init`: full starting parameter vector (default: `init` of each parameter).
- `fixed`: iterable of `name => value` pairs to hold constant (in addition to
  parameters fixed in the model).
- `bounds`: iterable of `name => (lo, hi)` pairs overriding model bounds.
- `hesse`: compute the covariance matrix as the inverse NLL Hessian.
"""
function fit(model::HistModel, data::Dataset=observed_data(model); init=nothing, fixed=(),
             bounds=(), hesse::Bool=true, maxiter::Int=200, tol::Real=1e-12)
    ps = model.parameters
    np = length(ps)
    theta0 = init === nothing ? [p.init for p in ps] : Float64.(collect(init))
    length(theta0) == np || throw(ArgumentError("init has length $(length(theta0)), expected $np"))
    isfixed = [p.fixed for p in ps]
    for (k, v) in fixed
        i = _param_index(model, k)
        theta0[i] = Float64(v)
        isfixed[i] = true
    end
    lower = [p.lower for p in ps]
    upper = [p.upper for p in ps]
    for (k, b) in bounds
        i = _param_index(model, k)
        lower[i], upper[i] = Float64(b[1]), Float64(b[2])
    end
    free = findall(!, isfixed)
    expand = x -> begin
        full = copyto!(similar(x, np), theta0)
        full[free] .= x
        full
    end
    f = x -> nll(model, expand(x), data)
    res = newton_minimize(f, theta0[free], lower[free], upper[free]; maxiter=maxiter, tol=tol)
    theta = expand(res.x)
    cov = zeros(np, np)
    if hesse && !isempty(free)
        cov[free, free] .= _inverse_hessian(ForwardDiff.hessian(f, res.x))
    end
    errs = sqrt.(max.(diag(cov), 0.0))
    return FitResult(theta, errs, cov, [p.name for p in ps], .!isfixed, res.fval, res.edm,
                     res.iterations, res.converged)
end

_param_index(model::HistModel, k::Integer) = Int(k)
function _param_index(model::HistModel, k::AbstractString)
    haskey(model.index, k) || throw(ArgumentError("unknown parameter $k"))
    return model.index[k]
end
_param_index(model::HistModel, k::Symbol) = _param_index(model, String(k))

function _inverse_hessian(H::AbstractMatrix)
    Hs = Symmetric(0.5 .* (H .+ H'))
    C = cholesky(Hs; check=false)
    issuccess(C) && return Matrix(inv(C))
    @warn "NLL Hessian is not positive definite; covariance from pseudo-inverse"
    return pinv(Matrix(Hs))
end
