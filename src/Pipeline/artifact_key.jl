"""
    artifact_key(parts...) -> String

Content key of an artifact: canonical hash of everything it depends on (input
signatures or upstream keys, configuration hashes, code hashes, hook ids).
"""
artifact_key(parts...) = canonical_hash(collect(Any, parts))
