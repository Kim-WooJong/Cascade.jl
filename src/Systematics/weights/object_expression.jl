"""
    object_expression(ex, object, k) -> expression

Rewrite an object-scope expression into the event-scope expression of the
`k`-th selected `object`: every field name `f` becomes `object.f[k]`
(function names, comparison operators and constants are kept).
"""
object_expression(ex::Symbol, object::AbstractString, k::Integer) =
    haskey(VECTOR_CONSTANTS, ex) ? ex : Expr(:ref, Expr(:., Symbol(object), QuoteNode(ex)), Int(k))

function object_expression(ex::Expr, object::AbstractString, k::Integer)
    if ex.head === :call
        return Expr(:call, ex.args[1], (object_expression(a, object, k) for a in ex.args[2:end])...)
    elseif ex.head === :comparison
        return Expr(:comparison, (isodd(i) ? object_expression(a, object, k) : a for (i, a) in enumerate(ex.args))...)
    end
    return Expr(ex.head, (object_expression(a, object, k) for a in ex.args)...)
end

object_expression(ex, object::AbstractString, k::Integer) = ex
