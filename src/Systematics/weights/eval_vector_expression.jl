const VECTOR_CONSTANTS = Dict{Symbol,Float64}(:pi => Float64(pi), :π => Float64(pi), :Inf => Inf, :NaN => NaN)

const VECTOR_FUNCTIONS = Dict{Symbol,Any}(
    :abs => abs, :sqrt => sqrt, :cbrt => cbrt, :exp => exp, :log => log, :log10 => log10,
    :sin => sin, :cos => cos, :tan => tan, :sinh => sinh, :cosh => cosh, :tanh => tanh,
    :atan => atan, :hypot => hypot, :min => min, :max => max, :floor => floor, :ceil => ceil,
    :round => round, :sign => sign, :isnan => isnan, :isfinite => isfinite, :ifelse => ifelse,
    :Float64 => Float64, :+ => +, :- => -, :* => *, :/ => /, :^ => ^, :! => !,
    :(==) => ==, :(!=) => !=, :< => <, :<= => <=, :> => >, :>= => >=)

"""
    eval_vector_expression(ex, resolve, n) -> AbstractVector

Evaluate a parsed expression element-wise over `n` rows. `resolve(node)` is
called first for every symbol and sub-expression and returns a column
(`AbstractVector` of length `n`) or `nothing` to evaluate the node itself.
Supported: numbers, booleans, `pi`/`Inf`/`NaN`, whitelisted functions and
operators, comparison chains, `&&`, `||` and `c ? a : b` (all element-wise).
Numbers give `Float64` columns, conditions `Bool` columns.
"""
function eval_vector_expression(ex, resolve, n::Integer)
    v = resolve(ex)
    if v !== nothing
        length(v) == n || throw(ArgumentError("column for $(ex) has $(length(v)) rows, expected $n"))
        return v
    end
    rec(x) = eval_vector_expression(x, resolve, n)
    ex isa Bool && return fill(ex, n)
    ex isa Real && return fill(Float64(ex), n)
    if ex isa Symbol
        haskey(VECTOR_CONSTANTS, ex) && return fill(VECTOR_CONSTANTS[ex], n)
        throw(ArgumentError("unknown name '$ex'"))
    elseif ex isa Expr
        h = ex.head
        if h === :call
            f = ex.args[1]
            (f isa Symbol && haskey(VECTOR_FUNCTIONS, f)) ||
                throw(ArgumentError("function '$(f)' is not allowed in correction inputs"))
            return broadcast(VECTOR_FUNCTIONS[f], map(rec, ex.args[2:end])...)
        elseif h === :comparison
            out = fill(true, n)
            for k in 2:2:length(ex.args)-1
                op = ex.args[k]
                (op isa Symbol && haskey(VECTOR_FUNCTIONS, op)) || throw(ArgumentError("unsupported comparison $(op)"))
                out .&= broadcast(VECTOR_FUNCTIONS[op], rec(ex.args[k-1]), rec(ex.args[k+1]))
            end
            return out
        elseif h === :&&
            return _bool_column(rec(ex.args[1])) .& _bool_column(rec(ex.args[2]))
        elseif h === :||
            return _bool_column(rec(ex.args[1])) .| _bool_column(rec(ex.args[2]))
        elseif h === :if
            return ifelse.(_bool_column(rec(ex.args[1])), rec(ex.args[2]), rec(ex.args[3]))
        end
        throw(ArgumentError("unsupported syntax '$(h)' in $(ex)"))
    end
    throw(ArgumentError("unsupported literal $(repr(ex))"))
end

function _bool_column(v)
    eltype(v) <: Bool || throw(ArgumentError("condition must be boolean, got $(eltype(v))"))
    return v
end
