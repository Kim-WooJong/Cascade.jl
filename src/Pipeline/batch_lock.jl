"""Execute under an OS advisory lock; process death releases it without stealing live claims.

Persistent lock files are never removed. Locks are local-host POSIX flock locks;
shared multi-host filesystems and external scheduler execution are unsupported.
"""
function batch_lock(f, path)
    Sys.isunix() || error("batch requires POSIX flock")
    batch_safe_path(path)
    mkpath(dirname(path))
    islink(path) && error("symlink batch lock")
    open(path, "a+") do io
        rc = ccall(:flock, Cint, (Cint, Cint), Base.fd(io), 2 | 4)
        rc == 0 || throw(ArgumentError("batch claim busy: $path"))
        try
            return f()
        finally
            ccall(:flock, Cint, (Cint, Cint), Base.fd(io), 8)
        end
    end
end
