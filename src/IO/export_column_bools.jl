function _export_column_bools(io, n)
    buffer = Vector{UInt8}(undef, min(n, 4096)); left = n
    while left > 0
        count = min(left, length(buffer)); read!(io, view(buffer, 1:count))
        all(i -> buffer[i] <= 1, 1:count) || error("invalid cols compatibility Bool bytes")
        left -= count
    end
    return nothing
end
