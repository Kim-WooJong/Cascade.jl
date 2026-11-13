"""Write JSON by same-directory atomic rename, never publishing a partial receipt."""
function batch_atomic_json(path, value)
    batch_safe_path(path)
    mkpath(dirname(path))
    tmp, io = mktemp(dirname(path))
    try
        JSON3.write(io, value)
        flush(io)
        close(io)
        Base.Filesystem.rename(tmp, path)
    finally
        isopen(io) && close(io)
        isfile(tmp) && rm(tmp)
    end
    return path
end
