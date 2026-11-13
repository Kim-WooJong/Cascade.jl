"""Return a stable complete relative-path/content checksum inventory of a directory."""
function batch_files(dir)
    files = Dict{String,String}()
    for (root, dirs, names) in walkdir(dir)
        any(d -> islink(joinpath(root, d)), dirs) && error("symlink directory in batch artifact")
        for name in names
            p = joinpath(root, name)
            islink(p) && error("symlink in batch artifact: $p")
            files[relpath(p, dir)] = bytes2hex(open(sha256, p))
        end
    end
    return files
end
