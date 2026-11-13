# Minimal JSON reader producing Dict{String,Any} / Vector{Any} / String /
# Int64 / UInt64 / Float64 / Bool / nothing.
#
# Numbers are converted exactly like RapidJSON does in correctionlib (default
# flags + kParseNanAndInfFlag, i.e. *without* kParseFullPrecisionFlag): the
# significand is accumulated in an integer up to 2^53 (then in a double, at most
# 17 significant digits) and scaled by a power-of-ten table. This is not always
# correctly rounded, and reproducing it makes bin edges and parameters
# bit-identical to the values correctionlib evaluates with. Integers without
# fraction/exponent stay integers ("-0" is the integer 0, as in RapidJSON).
# Duplicate object keys: the first occurrence wins (rapidjson FindMember).

const RJ_POW10 = [parse(Float64, "1e$n") for n in 0:308]

mutable struct JSONReader
    s::Vector{UInt8}
    pos::Int
end

@noinline json_error(r::JSONReader, msg::String) =
    throw(CorrectionError("JSON parse error: $msg at offset $(r.pos - 1)"))

@inline function peekb(r::JSONReader)
    return r.pos <= length(r.s) ? @inbounds(r.s[r.pos]) : 0x00
end

@inline function skip_json_ws!(r::JSONReader)
    s = r.s
    n = length(s)
    p = r.pos
    @inbounds while p <= n
        c = s[p]
        (c == 0x20 || c == 0x0a || c == 0x0d || c == 0x09) || break
        p += 1
    end
    r.pos = p
    return nothing
end

@inline function consume!(r::JSONReader, c::UInt8)
    if peekb(r) == c
        r.pos += 1
        return true
    end
    return false
end

@inline isdigitb(c::UInt8) = 0x30 <= c <= 0x39

function rj_fastpath(d::Float64, p::Int)
    p < -308 && return 0.0
    return p >= 0 ? d * RJ_POW10[p+1] : d / RJ_POW10[-p+1]
end

function rj_strtod_normal(d::Float64, p::Int)
    if p < -308
        d = rj_fastpath(d, -308)
        return rj_fastpath(d, p + 308)
    end
    return rj_fastpath(d, p)
end

function parse_json_number!(r::JSONReader)
    minus = consume!(r, UInt8('-'))
    i = UInt32(0)
    i64 = UInt64(0)
    use64bit = false
    significand_digit = 0
    d = 0.0
    use_nan_inf = false
    c = peekb(r)
    if c == UInt8('0')
        r.pos += 1
    elseif UInt8('1') <= c <= UInt8('9')
        i = UInt32(c - 0x30)
        r.pos += 1
        limit = minus ? UInt32(214748364) : UInt32(429496729)
        lastd = minus ? UInt8('8') : UInt8('5')
        while isdigitb(peekb(r))
            if i >= limit && (i != limit || peekb(r) > lastd)
                i64 = UInt64(i)
                use64bit = true
                break
            end
            i = i * UInt32(10) + UInt32(peekb(r) - 0x30)
            r.pos += 1
            significand_digit += 1
        end
    elseif c == UInt8('N') || c == UInt8('I')
        if consume!(r, UInt8('N'))
            if consume!(r, UInt8('a')) && consume!(r, UInt8('N'))
                d = NaN
                use_nan_inf = true
            end
        elseif consume!(r, UInt8('I'))
            if consume!(r, UInt8('n')) && consume!(r, UInt8('f'))
                d = minus ? -Inf : Inf
                use_nan_inf = true
                if peekb(r) == UInt8('i')
                    for ch in "inity"
                        consume!(r, UInt8(ch)) || json_error(r, "invalid value")
                    end
                end
            end
        end
        use_nan_inf || json_error(r, "invalid value")
    else
        json_error(r, "invalid value")
    end
    use_double = false
    if use64bit
        limit64 = minus ? 0x0CCCCCCCCCCCCCCC : 0x1999999999999999
        lastd = minus ? UInt8('8') : UInt8('5')
        while isdigitb(peekb(r))
            if i64 >= limit64 && (i64 != limit64 || peekb(r) > lastd)
                d = Float64(i64)
                use_double = true
                break
            end
            i64 = i64 * 10 + UInt64(peekb(r) - 0x30)
            r.pos += 1
            significand_digit += 1
        end
    end
    if use_double
        while isdigitb(peekb(r))
            d = d * 10 + Float64(peekb(r) - 0x30)
            r.pos += 1
        end
    end
    exp_frac = 0
    if !use_nan_inf && consume!(r, UInt8('.'))
        isdigitb(peekb(r)) || json_error(r, "missing fraction")
        if !use_double
            use64bit || (i64 = UInt64(i))
            while isdigitb(peekb(r))
                i64 > 0x001FFFFFFFFFFFFF && break
                i64 = i64 * 10 + UInt64(peekb(r) - 0x30)
                r.pos += 1
                exp_frac -= 1
                i64 != 0 && (significand_digit += 1)
            end
            d = Float64(i64)
            use_double = true
        end
        while isdigitb(peekb(r))
            if significand_digit < 17
                d = d * 10.0 + Float64(peekb(r) - 0x30)
                exp_frac -= 1
                d > 0.0 && (significand_digit += 1)
            end
            r.pos += 1
        end
    end
    exp = 0
    if !use_nan_inf && (consume!(r, UInt8('e')) || consume!(r, UInt8('E')))
        if !use_double
            d = use64bit ? Float64(i64) : Float64(i)
            use_double = true
        end
        exp_minus = false
        if consume!(r, UInt8('+'))
        elseif consume!(r, UInt8('-'))
            exp_minus = true
        end
        isdigitb(peekb(r)) || json_error(r, "missing exponent")
        exp = Int(peekb(r) - 0x30)
        r.pos += 1
        if exp_minus
            max_exp = (exp_frac + 2147483639) ÷ 10
            while isdigitb(peekb(r))
                exp = exp * 10 + Int(peekb(r) - 0x30)
                r.pos += 1
                if exp > max_exp
                    while isdigitb(peekb(r))
                        r.pos += 1
                    end
                end
            end
        else
            max_exp = 308 - exp_frac
            while isdigitb(peekb(r))
                exp = exp * 10 + Int(peekb(r) - 0x30)
                r.pos += 1
                exp > max_exp && json_error(r, "number too big")
            end
        end
        exp_minus && (exp = -exp)
    end
    if use_double
        d = rj_strtod_normal(d, exp + exp_frac)
        d > floatmax(Float64) && json_error(r, "number too big")
        return minus ? -d : d
    elseif use_nan_inf
        return d
    elseif use64bit
        return minus ? reinterpret(Int64, ~i64 + 1) : (i64 <= typemax(Int64) ? Int64(i64) : i64)
    else
        return minus ? -Int64(i) : Int64(i)
    end
end

function hexval(r::JSONReader, c::UInt8)
    UInt8('0') <= c <= UInt8('9') && return UInt32(c - UInt8('0'))
    UInt8('a') <= c <= UInt8('f') && return UInt32(c - UInt8('a') + 10)
    UInt8('A') <= c <= UInt8('F') && return UInt32(c - UInt8('A') + 10)
    json_error(r, "invalid unicode escape")
end

function parse_u4!(r::JSONReader)
    r.pos + 3 <= length(r.s) || json_error(r, "invalid unicode escape")
    v = UInt32(0)
    for k in 0:3
        v = (v << 4) | hexval(r, r.s[r.pos+k])
    end
    r.pos += 4
    return v
end

function parse_json_string!(r::JSONReader)
    s = r.s
    n = length(s)
    start = r.pos
    p = start
    # fast path: no escapes
    @inbounds while p <= n
        c = s[p]
        c == UInt8('"') && (r.pos = p + 1; return String(view(s, start:p-1)))
        c == UInt8('\\') && break
        c < 0x20 && json_error(r, "invalid string character")
        p += 1
    end
    p > n && json_error(r, "missing closing quote")
    io = IOBuffer()
    write(io, view(s, start:p-1))
    r.pos = p
    while true
        r.pos <= n || json_error(r, "missing closing quote")
        c = s[r.pos]
        r.pos += 1
        if c == UInt8('"')
            return String(take!(io))
        elseif c == UInt8('\\')
            r.pos <= n || json_error(r, "invalid escape")
            e = s[r.pos]
            r.pos += 1
            if e == UInt8('"') || e == UInt8('\\') || e == UInt8('/')
                write(io, e)
            elseif e == UInt8('b')
                write(io, 0x08)
            elseif e == UInt8('f')
                write(io, 0x0c)
            elseif e == UInt8('n')
                write(io, 0x0a)
            elseif e == UInt8('r')
                write(io, 0x0d)
            elseif e == UInt8('t')
                write(io, 0x09)
            elseif e == UInt8('u')
                u = parse_u4!(r)
                if 0xd800 <= u <= 0xdbff
                    (consume!(r, UInt8('\\')) && consume!(r, UInt8('u'))) || json_error(r, "invalid surrogate")
                    lo = parse_u4!(r)
                    0xdc00 <= lo <= 0xdfff || json_error(r, "invalid surrogate")
                    u = 0x10000 + ((u - 0xd800) << 10) + (lo - 0xdc00)
                end
                print(io, Char(u))
            else
                json_error(r, "invalid escape")
            end
        elseif c < 0x20
            json_error(r, "invalid string character")
        else
            write(io, c)
        end
    end
end

function expect_word!(r::JSONReader, w::String)
    for ch in w
        consume!(r, UInt8(ch)) || json_error(r, "invalid value")
    end
end

function parse_json_value!(r::JSONReader)
    skip_json_ws!(r)
    c = peekb(r)
    if c == UInt8('{')
        r.pos += 1
        d = Dict{String,Any}()
        skip_json_ws!(r)
        consume!(r, UInt8('}')) && return d
        while true
            skip_json_ws!(r)
            consume!(r, UInt8('"')) || json_error(r, "object member name expected")
            key = parse_json_string!(r)
            skip_json_ws!(r)
            consume!(r, UInt8(':')) || json_error(r, "colon expected")
            v = parse_json_value!(r)
            haskey(d, key) || (d[key] = v)
            skip_json_ws!(r)
            consume!(r, UInt8(',')) && continue
            consume!(r, UInt8('}')) && return d
            json_error(r, "comma or '}' expected")
        end
    elseif c == UInt8('[')
        r.pos += 1
        a = Any[]
        skip_json_ws!(r)
        consume!(r, UInt8(']')) && return a
        while true
            push!(a, parse_json_value!(r))
            skip_json_ws!(r)
            consume!(r, UInt8(',')) && continue
            consume!(r, UInt8(']')) && return a
            json_error(r, "comma or ']' expected")
        end
    elseif c == UInt8('"')
        r.pos += 1
        return parse_json_string!(r)
    elseif c == UInt8('t')
        expect_word!(r, "true")
        return true
    elseif c == UInt8('f')
        expect_word!(r, "false")
        return false
    elseif c == UInt8('n')
        expect_word!(r, "null")
        return nothing
    end
    return parse_json_number!(r)
end

"""
    read_json(data) -> Any

Parse JSON text (`AbstractString` or bytes) with correctionlib/RapidJSON number
semantics. Throws [`CorrectionError`](@ref) on malformed input.
"""
function read_json(data::AbstractVector{UInt8})
    r = JSONReader(data isa Vector{UInt8} ? data : Vector{UInt8}(data), 1)
    v = parse_json_value!(r)
    skip_json_ws!(r)
    r.pos <= length(r.s) && json_error(r, "the document root must not be followed by other values")
    return v
end
read_json(data::AbstractString) = read_json(Vector{UInt8}(codeunits(data)))
