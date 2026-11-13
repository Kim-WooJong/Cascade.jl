"""Write original typed columns as a genuine ROOT RNTuple; no derived EventTable values.

Caller owns staging, nonoverwrite and whole-bundle publication. The tested
UnROOT writer is eager, one cluster/one page per column, not a streaming API.
"""
function write_reduced_rntuple(path, cols; max_payload_bytes = 64_000_000)
    isdefined(UnROOT, :write_rntuple) && pkgversion(UnROOT) >= v"0.11.11" || error("UnROOT >=0.11.11 write_rntuple is required")
    current = abspath(path)
    while true
        islink(current) && error("symlink in reduced output path")
        parent = dirname(current)
        parent == current && break
        current = parent
    end
    ispath(path) && error("refusing to overwrite reduced output")
    order = sort!(collect(keys(cols)))
    n = length(cols[first(order)])
    schema, bytes = reduced_column_schema(cols, n; max_payload_bytes)
    values = Any[c isa Jagged ? [collect(c[i]) for i in 1:n] : c for c in (cols[k] for k in order)]
    table = NamedTuple{Tuple(Symbol.(order))}(Tuple(values))
    open(path, "w") do io
        UnROOT.write_rntuple(io, table; file_name = basename(path), rntuple_name = "Events", compression = 404)
    end
    filesize(path) < 256_000_000 || error("reduced encoded file exceeds conservative writer limit")
    return schema, bytes
end
