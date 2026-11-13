"""
    format_fixed(x, digits) -> String

Fixed-point decimal string of `x` with `digits` decimals (`"n/a"` for non-finite
`x`), without depending on Printf.
"""
function format_fixed(x::Real, digits::Integer)
    isfinite(x) || return "n/a"
    r = BigInt(round(abs(Float64(x)) * 10.0^digits))
    s = string(r)
    if digits > 0
        s = lpad(s, digits + 1, '0')
        s = s[1:end-digits] * "." * s[end-digits+1:end]
    end
    return x < 0 && r != 0 ? "-" * s : s
end
