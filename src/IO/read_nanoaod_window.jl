"""Read one primitive TTree branch window, guarding each basket before decoding.

Only overlapping baskets are decoded, one at a time. No whole-source event
mask, counter array or output padding is allocated. Recovered baskets are
explicitly unsupported by this bounded protocol.
"""
function read_nanoaod_window(file, tree, name, range; max_basket_bytes, max_window_bytes)
    lb = UnROOT.LazyBranch(file, string(tree, "/", name))
    length(lb) == Int(file[tree].fEntries) || error("branch event length disagrees with source tree: $name")
    T = eltype(lb); jagged = T <: AbstractVector; E = jagged ? eltype(T) : T
    haskey(COLFILE_TYPES, string(E)) || error("unsupported window primitive $E: $name")
    n = length(range)
    isempty(range) || (first(range) >= 1 && last(range) <= length(lb)) || error("window outside source")
    nb = UnROOT.numbaskets(lb.b); starts = lb.fEntry
    length(starts) >= nb + 1 && starts[1] == 0 && starts[nb+1] == length(lb) &&
        issorted(view(starts, 1:nb+1)) || error("unsupported or malformed basket index: $name")
    fixed = Int128(n) * (jagged ? 8 : sizeof(E)) + (jagged ? 8 : 0)
    fixed <= max_window_bytes || error("window fixed buffers exceed max_window_bytes")
    values = jagged ? E[] : Vector{E}(undef, n)
    offsets = jagged ? zeros(Int, n + 1) : Int[]
    peak = 0; requests = 0; compressed = 0
    if n > 0
        lo = searchsortedlast(view(starts, 1:nb+1), first(range) - 1)
        hi = searchsortedlast(view(starts, 1:nb+1), last(range) - 1)
        for ib in lo:hi
            pos = Int(lb.b.fBasketSeek[ib]); bytes = Int(lb.b.fBasketBytes[ib])
            16 <= bytes <= max_basket_bytes || error("compressed basket exceeds max_basket_bytes: $name")
            header = IOBuffer(UnROOT.read_seek_nb(file.fobj, pos, 16))
            declared = UnROOT.readtype(header, Int32)
            UnROOT.readtype(header, Int16)
            decoded = Int(UnROOT.readtype(header, Int32))
            declared == bytes && 0 <= decoded <= max_basket_bytes ||
                error("decoded basket exceeds max_basket_bytes before decompression: $name")
            peak = max(peak, decoded); requests += 1; compressed += bytes
            basket = UnROOT.basketarray(lb, ib)
            length(basket) == starts[ib+1] - starts[ib] || error("basket entry count mismatch: $name")
            for e in max(first(range), starts[ib]+1):min(last(range), starts[ib+1])
                row = e - first(range) + 1; localrow = e - starts[ib]
                if jagged
                    v = basket[localrow]
                    Int128(length(values) + length(v)) * sizeof(E) + fixed <= max_window_bytes ||
                        error("jagged window exceeds max_window_bytes; lower window_events or inspect oversized event")
                    append!(values, v); offsets[row+1] = length(values)
                else
                    values[row] = basket[localrow]
                end
            end
        end
    end
    return (jagged ? Jagged(values, offsets) : values),
        Dict("basket_requests" => requests, "compressed_bytes" => compressed, "peak_decoded_basket_bytes" => peak)
end
