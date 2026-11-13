"""
    chunk_id(path) -> String

Stable chunk identifier of an input file (first 16 hex digits of the SHA-256 of
its absolute path), independent of the position in the file list.
"""
chunk_id(path::AbstractString) = bytes2hex(sha256(abspath(path)))[1:16]
