# Parser for the TFormula subset accepted by correctionlib. It reproduces the
# PEG grammar of correctionlib's formula_ast.cc:
#   EXPRESSION <- ATOM (BINARYOP ATOM)*   precedence: || ; && ; == != ;
#                                          > < >= <= ; - + ; / * ; ^ (right assoc.)
#   ATOM   <- LITERAL / UATOM            LITERAL <- '-'? [0-9]+ ('.' [0-9]*)? ('e' '-'? [0-9]+)?
#   UATOM  <- '-'? (CALLU / CALLB / NAME / '(' EXPRESSION ')')
#   NAME   <- '[' n ']' (parameter) / 'x[' n ']' / [xyzt] (variable)
# Keyword choices (operators, function names) use longest match. Spaces and
# tabs are allowed between tokens. Sub-expressions made only of literals are
# folded at parse time (identical IEEE operations, so results are unchanged).

const FORMULA_BINOPS = (("||", F_OR, 1), ("&&", F_AND, 2), ("==", F_EQ, 3), ("!=", F_NE, 3),
                        (">=", F_GE, 4), ("<=", F_LE, 4), (">", F_GT, 4), ("<", F_LT, 4),
                        ("-", F_MINUS, 5), ("+", F_PLUS, 5), ("/", F_DIV, 6), ("*", F_TIMES, 6),
                        ("^", F_POW, 7))

const FORMULA_UNARY_FUNCS = (("log10", F_LOG10), ("log", F_LOG), ("exp", F_EXP), ("erf", F_ERF),
                             ("sqrt", F_SQRT), ("abs", F_ABS), ("cosh", F_COSH), ("cos", F_COS),
                             ("sinh", F_SINH), ("sin", F_SIN), ("tanh", F_TANH), ("tan", F_TAN),
                             ("acosh", F_ACOSH), ("acos", F_ACOS), ("asinh", F_ASINH), ("asin", F_ASIN),
                             ("atanh", F_ATANH), ("atan", F_ATAN))

const FORMULA_BINARY_FUNCS = (("atan2", F_ATAN2), ("pow", F_POW), ("max", F_MAX), ("min", F_MIN))

mutable struct FormulaParser
    s::Vector{UInt8}
    pos::Int
    expr::String
    nodes::Vector{FNode}
    variables::Vector{Int32}
    params::Vector{Float64}
    bind::Bool
    nparams::Int
end

@noinline function formula_parse_error(p::FormulaParser, msg::String = "syntax error")
    throw(CorrectionError("Failed to parse Formula expression at position $(p.pos - 1):\n$(p.expr)\n$msg"))
end

@inline peekc(p::FormulaParser, off::Int = 0) = p.pos + off <= length(p.s) ? p.s[p.pos+off] : 0x00
@inline isdigitc(c::UInt8) = 0x30 <= c <= 0x39

function skipws!(p::FormulaParser)
    while p.pos <= length(p.s) && (p.s[p.pos] == UInt8(' ') || p.s[p.pos] == UInt8('\t'))
        p.pos += 1
    end
end

function startswith_at(p::FormulaParser, word::String)
    w = codeunits(word)
    p.pos + length(w) - 1 <= length(p.s) || return false
    for j in eachindex(w)
        p.s[p.pos+j-1] == w[j] || return false
    end
    return true
end

function push_node!(p::FormulaParser, n::FNode)::Int32
    push!(p.nodes, n)
    return Int32(length(p.nodes))
end

push_literal!(p::FormulaParser, v::Float64) = push_node!(p, FNode(F_LITERAL, 0, 0, 0, v))

function push_unary!(p::FormulaParser, op::UInt8, a::Int32)::Int32
    na = p.nodes[a]
    if na.op == F_LITERAL && a == length(p.nodes)
        pop!(p.nodes)
        return push_literal!(p, apply_unary(op, na.value))
    end
    return push_node!(p, FNode(op, 0, a, 0, 0.0))
end

function push_binary!(p::FormulaParser, op::UInt8, a::Int32, b::Int32)::Int32
    na = p.nodes[a]
    nb = p.nodes[b]
    if na.op == F_LITERAL && nb.op == F_LITERAL && b == length(p.nodes) && a == b - 1
        pop!(p.nodes)
        pop!(p.nodes)
        return push_literal!(p, apply_binary(op, na.value, nb.value))
    end
    return push_node!(p, FNode(op, 0, a, b, 0.0))
end

# LITERAL token: returns the end position (exclusive) or 0 if no match.
function match_literal(p::FormulaParser)::Int
    s = p.s
    n = length(s)
    i = p.pos
    i <= n && s[i] == UInt8('-') && (i += 1)
    j = i
    while j <= n && isdigitc(s[j])
        j += 1
    end
    j == i && return 0
    if j <= n && s[j] == UInt8('.')
        j += 1
        while j <= n && isdigitc(s[j])
            j += 1
        end
    end
    if j <= n && s[j] == UInt8('e')
        k = j + 1
        k <= n && s[k] == UInt8('-') && (k += 1)
        m = k
        while m <= n && isdigitc(s[m])
            m += 1
        end
        m > k && (j = m)
    end
    return j
end

function parse_digits!(p::FormulaParser)::Int
    start = p.pos
    while p.pos <= length(p.s) && isdigitc(p.s[p.pos])
        p.pos += 1
    end
    p.pos == start && formula_parse_error(p, "expected digits")
    return parse(Int, String(p.s[start:p.pos-1]))
end

function expect_char!(p::FormulaParser, c::Char)
    skipws!(p)
    peekc(p) == UInt8(c) || formula_parse_error(p, "expected '$c'")
    p.pos += 1
    skipws!(p)
end

function variable_node!(p::FormulaParser, idx::Int)::Int32
    length(p.variables) > idx || throw(CorrectionError("Insufficient variables for formula"))
    return push_node!(p, FNode(F_VARIABLE, p.variables[idx+1], 0, 0, 0.0))
end

function parameter_node!(p::FormulaParser, idx::Int)::Int32
    if p.bind
        length(p.params) > idx || throw(CorrectionError("Insufficient parameters for formula"))
        return push_literal!(p, p.params[idx+1])
    end
    p.nparams = max(p.nparams, idx + 1)
    return push_node!(p, FNode(F_PARAMETER, Int32(idx + 1), 0, 0, 0.0))
end

function parse_call_or_name!(p::FormulaParser)::Int32
    # CALLU
    best = ""
    bestop = 0x00
    for (name, op) in FORMULA_UNARY_FUNCS
        if length(name) > length(best) && startswith_at(p, name)
            best, bestop = name, op
        end
    end
    if !isempty(best)
        save = p.pos
        p.pos += length(best)
        skipws!(p)
        if peekc(p) == UInt8('(')
            p.pos += 1
            skipws!(p)
            a = parse_expression!(p, 1)
            expect_char!(p, ')')
            return push_unary!(p, bestop, a)
        end
        p.pos = save
    end
    # CALLB
    best = ""
    for (name, op) in FORMULA_BINARY_FUNCS
        if length(name) > length(best) && startswith_at(p, name)
            best, bestop = name, op
        end
    end
    if !isempty(best)
        save = p.pos
        p.pos += length(best)
        skipws!(p)
        if peekc(p) == UInt8('(')
            p.pos += 1
            skipws!(p)
            a = parse_expression!(p, 1)
            expect_char!(p, ',')
            b = parse_expression!(p, 1)
            expect_char!(p, ')')
            return push_binary!(p, bestop, a, b)
        end
        p.pos = save
    end
    c = peekc(p)
    # PARAMETER
    if c == UInt8('[')
        p.pos += 1
        skipws!(p)
        idx = parse_digits!(p)
        expect_char!(p, ']')
        return parameter_node!(p, idx)
    end
    # VARIABLE: 'x[' n ']' or one of x y z t
    if c == UInt8('x') && peekc(p, 1) == UInt8('[') && isdigitc(peekc(p, 2))
        p.pos += 2
        idx = parse_digits!(p)
        peekc(p) == UInt8(']') || formula_parse_error(p, "expected ']'")
        p.pos += 1
        skipws!(p)
        return variable_node!(p, idx)
    end
    for (j, v) in enumerate((UInt8('x'), UInt8('y'), UInt8('z'), UInt8('t')))
        if c == v
            p.pos += 1
            skipws!(p)
            return variable_node!(p, j - 1)
        end
    end
    # parenthesized expression
    if c == UInt8('(')
        p.pos += 1
        skipws!(p)
        a = parse_expression!(p, 1)
        expect_char!(p, ')')
        return a
    end
    formula_parse_error(p)
end

function parse_atom!(p::FormulaParser)::Int32
    skipws!(p)
    stop = match_literal(p)
    if stop > 0
        value = parse(Float64, String(p.s[p.pos:stop-1]))
        p.pos = stop
        skipws!(p)
        return push_literal!(p, value)
    end
    if peekc(p) == UInt8('-')
        p.pos += 1
        skipws!(p)
        a = parse_call_or_name!(p)
        return push_unary!(p, F_NEG, a)
    end
    return parse_call_or_name!(p)
end

function match_binop(p::FormulaParser)
    for (tok, op, prec) in FORMULA_BINOPS
        startswith_at(p, tok) && return (op, prec, length(tok))
    end
    return (0x00, 0, 0)
end

function parse_expression!(p::FormulaParser, minprec::Int)::Int32
    lhs = parse_atom!(p)
    while true
        skipws!(p)
        op, prec, len = match_binop(p)
        (op == 0x00 || prec < minprec) && break
        p.pos += len
        skipws!(p)
        rhs = parse_expression!(p, op == F_POW ? prec : prec + 1)
        lhs = push_binary!(p, op, lhs, rhs)
    end
    return lhs
end

"""
    parse_tformula(expr, variables, params, bind) -> FormulaAst

`variables[i]` is the input index used for the i-th formula variable
(x, y, z, t or x[i-1]). With `bind = true` parameters `[i]` are replaced by
`params[i+1]`; otherwise they are left as parameter nodes (generic formulas).
"""
function parse_tformula(expr::String, variables::Vector{Int32}, params::Vector{Float64}, bind::Bool)
    p = FormulaParser(collect(codeunits(expr)), 1, expr, FNode[], variables, params, bind, 0)
    skipws!(p)
    root = parse_expression!(p, 1)
    skipws!(p)
    p.pos <= length(p.s) && formula_parse_error(p, "unexpected trailing input")
    return FormulaAst(p.nodes, root, p.nparams)
end
