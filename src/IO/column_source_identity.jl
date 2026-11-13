"""Bind mapping and path identities independently, without decoding stat device IDs.

Linux virtual/stacked filesystems can expose different mapping and path inode/
device namespaces. Compare mappings to mappings and path stats to path stats.
Unparseable/unavailable mapping evidence falls back only before binding; loss
of evidence after an expected identity was recorded is an error, not fallback.
This detects ordinary replacement/drift, not adversarial in-place modification.
"""
function column_source_identity(src::NanoAODSource; expected = nothing)
    array = src.file.fobj.mmap_ary
    address = UInt(pointer(array))
    binding = nothing
    if Sys.islinux() && isfile("/proc/self/maps")
        try
            for line in eachline("/proc/self/maps")
                fields = split(line; limit = 6)
                length(fields) >= 5 || continue
                bounds = split(fields[1], '-')
                length(bounds) == 2 || continue
                lo = tryparse(UInt, bounds[1]; base = 16)
                hi = tryparse(UInt, bounds[2]; base = 16)
                (lo === nothing || hi === nothing) && continue
                lo <= address < hi || continue
                offset = tryparse(UInt, fields[3]; base = 16)
                device = split(fields[4], ':')
                offset == 0 && length(device) == 2 || break
                major = tryparse(UInt, device[1]; base = 16)
                minor = tryparse(UInt, device[2]; base = 16)
                inode = tryparse(UInt, fields[5])
                (major === nothing || minor === nothing || inode === nothing) && break
                binding = (major, minor, inode)
                break
            end
        catch e
            (e isa SystemError || e isa Base.IOError) || rethrow()
        end
    end
    if binding === nothing
        expected === nothing || error("column reader mapping identity unavailable after binding: $(src.path)")
        return nothing
    end
    st = stat(src.path)
    path_identity = (device = st.device, inode = st.inode, size = st.size, mtime = st.mtime, ctime = st.ctime)
    return column_source_identity(binding, length(array), path_identity; expected, path = src.path)
end

"""Pure composite construction/check seam; mapping and path namespaces need not agree."""
function column_source_identity(mapping, mapped_length::Integer, path_identity::NamedTuple;
                                expected = nothing, path = "")
    if mapping === nothing
        expected === nothing || error("column reader mapping identity unavailable after binding: $path")
        return nothing
    end
    mapped_length == path_identity.size || error("column reader mapped length/path size drift: $path")
    identity = (mapping = (major = mapping[1], minor = mapping[2], inode = mapping[3], length = mapped_length),
                path = path_identity)
    expected === nothing || identity == expected || error("column reader source identity drift: $path")
    return identity
end
