"""Bind the borrowed mapping to its current pathname, without another ROOTFile.

Composite map/path stats alone cannot reject replacement before the first bind:
they can pair an old mmap with a new pathname. Linux map_files readlink supplies
the mapping's actual dentry path, independently of device/inode namespaces.
Unavailable evidence falls back only before binding; ordinary drift is an error.
"""
function decode_source_identity(src::NanoAODSource; expected = nothing)
    identity = column_source_identity(src; expected = expected === nothing ? nothing : expected.identity)
    identity === nothing && return nothing
    address = UInt(pointer(src.file.fobj.mmap_ary))
    mapped = nothing
    try
        for line in eachline("/proc/self/maps")
            fields = split(line;limit=6);length(fields)>=5 || continue
            bounds = split(fields[1],'-');length(bounds)==2 || continue
            lo = tryparse(UInt,bounds[1];base=16);hi = tryparse(UInt,bounds[2];base=16)
            (lo === nothing || hi === nothing || !(lo<=address<hi)) && continue
            mapped = readlink(string("/proc/self/map_files/",fields[1]))
            break
        end
    catch e
        (e isa SystemError || e isa Base.IOError) || rethrow()
    end
    if mapped === nothing
        expected === nothing || error("decode mapped pathname unavailable after binding")
        return nothing
    end
    mapped == realpath(src.path) || error("decode mapped pathname/input replacement drift: $(src.path)")
    expected === nothing || mapped == expected.mapped_path || error("decode mapped pathname changed after binding")
    return (identity = identity, mapped_path = mapped)
end
