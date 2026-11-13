# Elementary functions with C/libm semantics (NaN instead of DomainError),
# matching what correctionlib's C++ evaluator returns.
@inline c_log(x::Float64) = x < 0.0 ? NaN : log(x)
@inline c_log10(x::Float64) = x < 0.0 ? NaN : log10(x)
@inline c_sqrt(x::Float64) = x < 0.0 ? NaN : sqrt(x)
@inline c_sin(x::Float64) = isinf(x) ? NaN : sin(x)
@inline c_cos(x::Float64) = isinf(x) ? NaN : cos(x)
@inline c_tan(x::Float64) = isinf(x) ? NaN : tan(x)
@inline c_acos(x::Float64) = abs(x) > 1.0 ? NaN : acos(x)
@inline c_asin(x::Float64) = abs(x) > 1.0 ? NaN : asin(x)
@inline c_acosh(x::Float64) = x < 1.0 ? NaN : acosh(x)
@inline c_atanh(x::Float64) = abs(x) > 1.0 ? NaN : atanh(x)
# std::max / std::min argument order semantics (matter for NaN and signed zeros)
@inline c_max(a::Float64, b::Float64) = a < b ? b : a
@inline c_min(a::Float64, b::Float64) = b < a ? b : a

function c_pow(x::Float64, y::Float64)::Float64
    (y == 0.0 || x == 1.0) && return 1.0
    (isnan(x) || isnan(y)) && return NaN
    if isinf(y)
        ax = abs(x)
        ax == 1.0 && return 1.0
        return (ax < 1.0) == (y > 0.0) ? 0.0 : Inf
    end
    if x < 0.0 && !isinteger(y)
        isinf(x) && return y < 0.0 ? 0.0 : Inf
        return NaN
    end
    return x^y
end
