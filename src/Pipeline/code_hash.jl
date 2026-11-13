const _CODE_HASHES = Dict{String,String}()
const _CODE_LOCK = ReentrantLock()

"""
    code_hash(areas) -> String

SHA-256 over the source files (relative path and content) of the given
`src/<Area>` folders, plus the Julia version. Cached per process.
"""
function code_hash(areas::AbstractVector{<:AbstractString})
    srcdir = dirname(@__DIR__)
    parts = String[string(VERSION)]
    for area in sort(String.(areas))
        h = lock(_CODE_LOCK) do
            get!(_CODE_HASHES, area) do
                ctx = SHA.SHA256_CTX()
                dir = joinpath(srcdir, area)
                if isdir(dir)
                    for (root, _, files) in walkdir(dir), f in sort(files)
                        p = joinpath(root, f)
                        SHA.update!(ctx, Vector{UInt8}(relpath(p, srcdir)))
                        SHA.update!(ctx, read(p))
                    end
                end
                bytes2hex(SHA.digest!(ctx))
            end
        end
        push!(parts, string(area, "=", h))
    end
    return bytes2hex(sha256(join(parts, ";")))
end
