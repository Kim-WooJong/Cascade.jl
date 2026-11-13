"""
    VariationConfig

Expression-based weight variation (MC only). `up` and `down` are event
expressions giving multiplicative factors with respect to the nominal weight.
Variations from correction sets are added by the `correct` step hook instead.
"""
struct VariationConfig
    name::String
    up::String
    down::String
end
