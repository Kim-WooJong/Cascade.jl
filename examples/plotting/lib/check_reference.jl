"""
    check_reference(name, value, reference; digits) -> Bool

Print and return whether `value` rounded to `digits` decimals equals `reference`.
"""
function check_reference(name::AbstractString, value::Real, reference::Real; digits::Integer)
    ok = round(value; digits) == reference
    println(rpad(name, 34), rpad(string(round(value; digits)), 14), " reference ", rpad(string(reference), 12),
            ok ? "PASS" : "FAIL")
    return ok
end
