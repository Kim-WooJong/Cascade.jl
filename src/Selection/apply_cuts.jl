"""
    apply_cuts(cuts::Tuple, sel, ctx, i) -> (passed::Int, built_through::Int)

Evaluate the sequential cut kernels for event `i` until the first failure,
materialising only objects due at each attempted cut. `built_through` includes
the failing cut: its objects are already fresh even when it did not pass.
Tuple recursion keeps every kernel call statically dispatched.
"""
@inline apply_cuts(cuts::Tuple, sel, ctx, i) = _apply(cuts, sel, ctx, i, 0, 0)

@inline _apply(::Tuple{}, sel, ctx, i, s, built) = (s, built)
@inline function _apply(cuts::Tuple, sel, ctx, i, s, built)
    k = s + 1
    if sel.mat_at != 0 && k >= sel.mat_at
        sel.materialize(ctx, i, built, k)
        built = k
    end
    first(cuts)(ctx, i) || return (s, built)
    return _apply(Base.tail(cuts), sel, ctx, i, k, built)
end
