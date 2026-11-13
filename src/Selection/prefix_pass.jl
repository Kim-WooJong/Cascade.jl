"""
    prefix_pass!(needed, sel, ctx, n)

`needed[i]` = event `i` can reach object materialization or be retained by an
earlier region. Only the prefix before `min(sel.mat_at, sel.keep_stage + 1)`
is required. Entered via `Base.invokelatest`.
"""
function prefix_pass!(needed::Vector{Bool}, sel::CompiledSelection, ctx, n::Int)
    m = min(sel.mat_at - 1, sel.keep_stage)
    for i in 1:n
        needed[i] = _prefix(sel.cuts, ctx, i, 1, m)
    end
    return needed
end

@inline _prefix(::Tuple{}, ctx, i, k, m) = true
@inline function _prefix(c::Tuple, ctx, i, k, m)
    k > m && return true
    first(c)(ctx, i) || return false
    return _prefix(Base.tail(c), ctx, i, k + 1, m)
end
