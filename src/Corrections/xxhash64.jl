# xxHash upstream: Copyright (c) 2012-2021 Yann Collet, BSD-2-Clause.
# Full upstream notice and compatibility scope: ../../THIRD_PARTY.md.
# XXH64 (xxHash, seed 0 by default) over a sequence of 64-bit little-endian
# words, as used by correctionlib's HashPRNG to seed its generator.
const XXH_P1 = 0x9E3779B185EBCA87
const XXH_P2 = 0xC2B2AE3D27D4EB4F
const XXH_P3 = 0x165667B19E3779F9
const XXH_P4 = 0x85EBCA77C2B2AE63
const XXH_P5 = 0x27D4EB2F165667C5

@inline xxh64_round(acc::UInt64, input::UInt64) = bitrotate(acc + input * XXH_P2, 31) * XXH_P1
@inline xxh64_merge(acc::UInt64, val::UInt64) = (acc ⊻ xxh64_round(UInt64(0), val)) * XXH_P1 + XXH_P4

"""
    xxh64_words(word, m, seed=0) -> UInt64

XXH64 digest of the `8m` bytes formed by the words `word(1), ..., word(m)`
laid out little-endian.
"""
@inline function xxh64_words(word::F, m::Int, seed::UInt64 = UInt64(0)) where {F}
    i = 1
    if m >= 4
        v1 = seed + XXH_P1 + XXH_P2
        v2 = seed + XXH_P2
        v3 = seed
        v4 = seed - XXH_P1
        while i + 3 <= m
            v1 = xxh64_round(v1, word(i))
            v2 = xxh64_round(v2, word(i + 1))
            v3 = xxh64_round(v3, word(i + 2))
            v4 = xxh64_round(v4, word(i + 3))
            i += 4
        end
        h = bitrotate(v1, 1) + bitrotate(v2, 7) + bitrotate(v3, 12) + bitrotate(v4, 18)
        h = xxh64_merge(h, v1)
        h = xxh64_merge(h, v2)
        h = xxh64_merge(h, v3)
        h = xxh64_merge(h, v4)
    else
        h = seed + XXH_P5
    end
    h += UInt64(8m)
    while i <= m
        h ⊻= xxh64_round(UInt64(0), word(i))
        h = bitrotate(h, 27) * XXH_P1 + XXH_P4
        i += 1
    end
    h ⊻= h >> 33
    h *= XXH_P2
    h ⊻= h >> 29
    h *= XXH_P3
    h ⊻= h >> 32
    return h
end
