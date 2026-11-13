"""
    newton_minimize(f, x0, lower, upper; maxiter=200, tol=1e-12)

Box-constrained minimisation of a smooth function with a projected,
Levenberg-damped Newton method. Gradient and Hessian are exact
(ForwardDiff). Variables at a bound whose gradient points outward are frozen
for that step. Converges when the estimated distance to minimum
`edm = g' H^-1 g / 2` (on the free set) drops below `tol`.

Returns a named tuple `(x, fval, edm, iterations, converged)`.
"""
function newton_minimize(f, x0::AbstractVector{<:Real}, lower::AbstractVector{<:Real},
                         upper::AbstractVector{<:Real}; maxiter::Int=200, tol::Real=1e-12)
    n = length(x0)
    x = clamp.(Float64.(x0), lower, upper)
    fx = f(x)
    isfinite(fx) || throw(ArgumentError("objective is not finite at the starting point"))
    n == 0 && return (x=x, fval=fx, edm=0.0, iterations=0, converged=true)
    damp = 0.0
    edm = Inf
    iter = 0
    converged = false
    while iter < maxiter
        iter += 1
        g = ForwardDiff.gradient(f, x)
        H = ForwardDiff.hessian(f, x)
        H = 0.5 .* (H .+ H')
        free = [!((x[i] <= lower[i] && g[i] > 0) || (x[i] >= upper[i] && g[i] < 0)) for i in 1:n]
        fi = findall(free)
        if isempty(fi)
            edm = 0.0
            converged = true
            break
        end
        gf = g[fi]
        Hf = H[fi, fi]
        C0 = cholesky(Symmetric(Hf); check=false)
        if issuccess(C0)
            step = -(C0 \ gf)
            edm = -0.5 * dot(gf, step)
            if edm < tol
                # Final full Newton step to reach machine precision (kept only if not worse).
                xn = copy(x)
                xn[fi] .+= step
                xn .= clamp.(xn, lower, upper)
                fn = f(xn)
                isfinite(fn) && fn <= fx && ((x, fx) = (xn, fn))
                converged = true
                break
            end
        else
            edm = Inf
            damp = max(damp, 1e-4)
        end
        dscale = max.(abs.(diag(Hf)), 1e-12)
        accepted = false
        for _ in 1:40
            C = damp == 0 ? C0 : cholesky(Symmetric(Hf + damp * Diagonal(dscale)); check=false)
            if !issuccess(C)
                damp = damp == 0 ? 1e-4 : 10 * damp
                continue
            end
            p = -(C \ gf)
            t = 1.0
            while t > 1e-12
                xn = copy(x)
                xn[fi] .+= t .* p
                xn .= clamp.(xn, lower, upper)
                xn == x && break
                fn = f(xn)
                if isfinite(fn) && fn <= fx + 1e-4 * dot(g, xn .- x)
                    x, fx = xn, fn
                    accepted = true
                    break
                end
                t /= 2
            end
            accepted && break
            damp = damp == 0 ? 1e-4 : 10 * damp
        end
        if !accepted
            # No decrease possible at machine precision: accept if close to minimum.
            converged = edm < 1e-6
            break
        end
        damp = damp < 1e-8 ? 0.0 : damp / 10
    end
    return (x=x, fval=fx, edm=edm, iterations=iter, converged=converged)
end
