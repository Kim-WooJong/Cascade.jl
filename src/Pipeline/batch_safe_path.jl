"""Reject preexisting symlink ancestry before batch filesystem writes or process launch.

Optionally require lexical containment in root. This is not protection against
hostile concurrent filesystem replacement; the local workspace must be trusted.
"""
function batch_safe_path(path; root = nothing)
    p = abspath(path)
    if root !== nothing
        rel = relpath(p, abspath(root))
        (rel == ".." || startswith(rel, "../") || isabspath(rel)) &&
            error("batch path escapes root: $path")
    end
    current = p
    while true
        islink(current) && error("symlink batch path: $current")
        parent = dirname(current)
        parent == current && break
        current = parent
    end
    return p
end
