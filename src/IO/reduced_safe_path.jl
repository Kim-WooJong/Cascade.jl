"""Resolve a contained regular bundle artifact without symlink ancestry."""
function reduced_safe_path(root, relative)
    relative isa AbstractString && !isabspath(relative) || error("unsafe reduced artifact path")
    p = normpath(joinpath(root, relative)); base = abspath(root)
    startswith(p, base * string(Base.Filesystem.path_separator)) || error("reduced artifact outside bundle")
    current = p
    while true
        islink(current) && error("symlink in reduced bundle")
        parent = dirname(current); parent == current && break; current = parent
    end
    isfile(p) || error("missing reduced artifact: $p")
    return p
end
