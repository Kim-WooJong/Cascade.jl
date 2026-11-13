# PCG upstream: Copyright (c) 2014-2017 Melissa O'Neill and contributors (MIT).
# Generator notice and external behavioral references: ../../THIRD_PARTY.md.
# pcg32_oneseq (pcg-cpp oneseq_xsh_rr_64_32) and the libstdc++ distributions
# used by correctionlib's HashPRNG. The generator state is threaded through
# explicitly so no heap object is needed.
const PCG_MULT = 0x5851f42d4c957f2d   # 6364136223846793005
const PCG_INC = 0x14057b7ef767814f    # 1442695040888963407

"""State after `pcg32_oneseq gen; gen.seed(seed)`."""
@inline pcg32_seed(seed::UInt64) = (seed + PCG_INC) * PCG_MULT + PCG_INC

"""Next 32-bit output and the new state (output uses the previous state)."""
@inline function pcg32_next(state::UInt64)
    xorshifted = (((state >> 18) ⊻ state) >> 27) % UInt32
    rot = (state >> 59) % Int
    return bitrotate(xorshifted, -rot), state * PCG_MULT + PCG_INC
end

"""libstdc++ std::generate_canonical<double, 53> for a 32-bit engine."""
@inline function pcg32_canonical(state::UInt64)
    g1, state = pcg32_next(state)
    g2, state = pcg32_next(state)
    s = Float64(g1)
    s += Float64(g2) * 4294967296.0
    r = s / 18446744073709551616.0
    r >= 1.0 && (r = prevfloat(1.0))
    return r, state
end

"""std::uniform_real_distribution<double>(0, 1)."""
@inline function pcg32_stdflat(state::UInt64)
    r, _ = pcg32_canonical(state)
    return r
end

"""std::normal_distribution<double>(0, 1), libstdc++ Marsaglia polar method."""
function pcg32_stdnormal(state::UInt64)
    while true
        a, state = pcg32_canonical(state)
        b, state = pcg32_canonical(state)
        x = 2.0 * a - 1.0
        y = 2.0 * b - 1.0
        r2 = x * x + y * y
        if !(r2 > 1.0 || r2 == 0.0)
            mult = sqrt(-2.0 * log(r2) / r2)
            return y * mult
        end
    end
end

"""correctionlib's own polar-method normal draw on raw 32-bit outputs."""
function pcg32_normal(state::UInt64)
    while true
        g1, state = pcg32_next(state)
        g2, state = pcg32_next(state)
        u = ldexp(Float64(g1), -31) - 1.0
        v = ldexp(Float64(g2), -31) - 1.0
        s = u * u + v * v
        if !(s >= 1.0 || s == 0.0)
            return u * sqrt(-2.0 * log(s) / s)
        end
    end
end
