# Flat expression tree of a TFormula and its evaluation. Operation codes and
# semantics mirror correctionlib's FormulaAst.
const F_LITERAL = 0x01
const F_VARIABLE = 0x02
const F_PARAMETER = 0x03
# unary operations
const F_NEG = 0x10
const F_LOG = 0x11
const F_LOG10 = 0x12
const F_EXP = 0x13
const F_ERF = 0x14
const F_SQRT = 0x15
const F_ABS = 0x16
const F_COS = 0x17
const F_SIN = 0x18
const F_TAN = 0x19
const F_ACOS = 0x1a
const F_ASIN = 0x1b
const F_ATAN = 0x1c
const F_COSH = 0x1d
const F_SINH = 0x1e
const F_TANH = 0x1f
const F_ACOSH = 0x20
const F_ASINH = 0x21
const F_ATANH = 0x22
# binary operations
const F_OR = 0x30
const F_AND = 0x31
const F_EQ = 0x32
const F_NE = 0x33
const F_GT = 0x34
const F_LT = 0x35
const F_GE = 0x36
const F_LE = 0x37
const F_MINUS = 0x38
const F_PLUS = 0x39
const F_DIV = 0x3a
const F_TIMES = 0x3b
const F_POW = 0x3c
const F_ATAN2 = 0x3d
const F_MAX = 0x3e
const F_MIN = 0x3f

struct FNode
    op::UInt8
    index::Int32    # variable: 1-based input index; parameter: 1-based parameter index
    left::Int32
    right::Int32
    value::Float64  # literal value
end

struct FormulaAst
    nodes::Vector{FNode}
    root::Int32
    nparams::Int    # number of parameters required at evaluation (unbound formulas)
end

isunary_op(op::UInt8) = F_NEG <= op <= F_ATANH

@inline function apply_unary(op::UInt8, a::Float64)::Float64
    op == F_NEG && return -a
    op == F_LOG && return c_log(a)
    op == F_LOG10 && return c_log10(a)
    op == F_EXP && return exp(a)
    op == F_SQRT && return c_sqrt(a)
    op == F_ABS && return abs(a)
    op == F_ERF && return c_erf(a)
    op == F_COS && return c_cos(a)
    op == F_SIN && return c_sin(a)
    op == F_TAN && return c_tan(a)
    op == F_ACOS && return c_acos(a)
    op == F_ASIN && return c_asin(a)
    op == F_ATAN && return atan(a)
    op == F_COSH && return cosh(a)
    op == F_SINH && return sinh(a)
    op == F_TANH && return tanh(a)
    op == F_ACOSH && return c_acosh(a)
    op == F_ASINH && return asinh(a)
    op == F_ATANH && return c_atanh(a)
    throw(CorrectionError("Unknown unary formula operation"))
end

@inline function apply_binary(op::UInt8, a::Float64, b::Float64)::Float64
    op == F_TIMES && return a * b
    op == F_PLUS && return a + b
    op == F_MINUS && return a - b
    op == F_DIV && return a / b
    op == F_MAX && return c_max(a, b)
    op == F_MIN && return c_min(a, b)
    op == F_POW && return c_pow(a, b)
    op == F_OR && return ((a != 0.0) || (b != 0.0)) ? 1.0 : 0.0
    op == F_AND && return ((a != 0.0) && (b != 0.0)) ? 1.0 : 0.0
    op == F_EQ && return a == b ? 1.0 : 0.0
    op == F_NE && return a != b ? 1.0 : 0.0
    op == F_GT && return a > b ? 1.0 : 0.0
    op == F_LT && return a < b ? 1.0 : 0.0
    op == F_GE && return a >= b ? 1.0 : 0.0
    op == F_LE && return a <= b ? 1.0 : 0.0
    op == F_ATAN2 && return atan(a, b)
    throw(CorrectionError("Unknown binary formula operation"))
end

"""Evaluate node `i` of `ast` for real input values `x` and parameters `p`."""
function feval(ast::FormulaAst, i::Int32, x::NTuple{N,Float64}, p::Vector{Float64})::Float64 where {N}
    n = @inbounds ast.nodes[i]
    op = n.op
    op == F_LITERAL && return n.value
    op == F_VARIABLE && return x[n.index]
    op == F_PARAMETER && return @inbounds p[n.index]
    if isunary_op(op)
        return apply_unary(op, feval(ast, n.left, x, p))
    end
    a = feval(ast, n.left, x, p)
    b = feval(ast, n.right, x, p)
    return apply_binary(op, a, b)
end

"""Copy of `ast` with variable input indices translated through `map`."""
function remap_formula_ast(ast::FormulaAst, map::Vector{Int32})
    nodes = [n.op == F_VARIABLE ? FNode(n.op, map[n.index], n.left, n.right, n.value) : n for n in ast.nodes]
    return FormulaAst(nodes, ast.root, ast.nparams)
end
