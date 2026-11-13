"""Verify persisted corrected-column theory semantics before histogram cache reuse."""
function verify_correct_extraction(cfg, sample, path)
    payload = read_column_file(path)
    verify_correct_extraction(cfg, sample, payload[2], payload[3])
    return nothing
end

# Identical semantic check for freshly written in-memory and persisted payloads.
function verify_correct_extraction(cfg, sample, meta, labels; expected = theory_extraction(cfg; samples = [sample]))
    manifest = get(meta, "theory_extraction", Dict{String,Any}())
    validate_theory_manifest(manifest, [(sample.name, label) for label in labels])
    canonical_hash(manifest) == canonical_hash(expected) ||
        throw(ArgumentError("stale/missing theory extraction contract for $(sample.name); rerun correct before histogram"))
    return nothing
end
