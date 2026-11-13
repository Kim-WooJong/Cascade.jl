function _export_column_offsets(io, n, content_length)
    buffer = Vector{Int64}(undef, min(n + 1, 4096))
    left = n + 1; index = 0; previous = Int64(0)
    while left > 0
        count = min(left, length(buffer)); read!(io, view(buffer, 1:count))
        for i in 1:count
            offset = buffer[i]
            0 <= offset <= content_length && offset >= previous || error("invalid cols compatibility offsets before allocation")
            index == 0 && offset != 0 && error("cols compatibility first offset must be zero")
            previous = offset; index += 1
        end
        left -= count
    end
    previous == content_length || error("cols compatibility final offset disagrees with content length")
    return nothing
end
