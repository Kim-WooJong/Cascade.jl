"""Canonical normalization ownership using persisted identity without reopening originals.

Meaningful device/inode wins; realpath is descriptive in that case. Sources
without a usable inode fall back to their persisted canonical absolute path.
This is file-population identity, not event/collision/content deduplication.
"""
function population_identity(population::AbstractDict)
    device = tryparse(BigInt, string(get(population, "device", "")))
    inode = tryparse(BigInt, string(get(population, "inode", "")))
    if device !== nothing && inode !== nothing && device >= 0 && inode > 0
        return canonical_hash(Dict("identity" => "device_inode", "device" => string(device), "inode" => string(inode)))
    end
    path = get(population, "realpath", nothing)
    path isa AbstractString && !isempty(path) && isabspath(path) || error("population has neither usable inode nor canonical absolute path")
    return canonical_hash(Dict("identity" => "canonical_path", "realpath" => normpath(path)))
end
