const _SET_CACHE = Dict{Tuple{String,Float64,Int},CorrectionSet}()
const _SET_LOCK = ReentrantLock()

"""
    cached_correctionset(path) -> CorrectionSet

Load a correctionlib file once per process (thread-safe). The cache key
includes the file modification time and size, so a changed file is reloaded.
"""
function cached_correctionset(path::AbstractString)
    p = abspath(path)
    isfile(p) || throw(ArgumentError("correction set not found: $p"))
    key = (p, mtime(p), Int(filesize(p)))
    return lock(_SET_LOCK) do
        get!(() -> load_correctionset(p), _SET_CACHE, key)
    end
end
