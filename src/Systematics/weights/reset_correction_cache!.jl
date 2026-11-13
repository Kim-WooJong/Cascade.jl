"""
    reset_correction_cache!()

Drop process-local parsed weight payloads before a new correct-step batch.
Artifact keys use content hashes, whereas per-chunk payload lookup uses cheap
file metadata. Resetting once per batch also covers same-size replacements
that preserve timestamps, without hashing large JSON payloads per event/chunk.
"""
function reset_correction_cache!()
    lock(_SET_LOCK) do
        empty!(_SET_CACHE)
    end
    return nothing
end
