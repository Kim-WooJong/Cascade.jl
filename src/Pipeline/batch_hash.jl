"""Hash the JSON wire representation, including JSON3 integral-number normalization.

Config canonical hashes distinguish 1 from 1.0; JSON3 decodes integral JSON
number tokens as Int. Normalize through the same reader before batch hashes
so persisted contracts round-trip without changing existing physics cache keys.
"""
function batch_hash(value)
    return canonical_hash(_jsdict(JSON3.read(JSON3.write(value))))
end
