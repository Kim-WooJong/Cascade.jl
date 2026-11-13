"""
    parse_expression(s::AbstractString) -> Union{Expr,Symbol,Number}

Parse one expression with Julia syntax. Statements, assignments and multiple
expressions are rejected.
"""
function parse_expression(s::AbstractString)
    ex = try
        Meta.parse(s; raise = true)
    catch e
        throw(ArgumentError("cannot parse expression \"$s\": $(sprint(showerror, e))"))
    end
    ex isa Expr && ex.head in (:toplevel, :block, :(=), :function, :macrocall, :incomplete, :error) &&
        throw(ArgumentError("expression \"$s\" must be a single expression"))
    return ex
end
