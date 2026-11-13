"""Bound source events, uncompressed branches and estimated eager buffers before selection.

The buffer estimate is conservative accounting, not an OS RSS reservation.
"""
function reduced_source_limits(src, names, options; output_columns = 0, variations = 1)
    n = nevents(src)
    n <= options["max_events"] || error("source exceeds reduced max_events; no automatic shards")
    length(names) + 1 <= 256 || error("reduced schema exceeds 256-column conservative limit")
    bytes = Int128(0); lists = 0
    if src isa NanoAODSource
        for name in names
            branch = src.file[string(src.tree, "/", name)]
            hasproperty(branch, :fTotBytes) || error("cannot bound uncompressed source branch $name")
            bytes += Int128(branch.fTotBytes)
            eltype(UnROOT.LazyBranch(src.file, string(src.tree, "/", name))) <: AbstractVector && (lists += 1)
        end
        bytes <= options["max_payload_bytes"] || error("source branches exceed conservative uncompressed payload limit")
    elseif src isa ColumnFileSource
        _, bytes = reduced_column_schema(src.cols, n; max_payload_bytes = options["max_payload_bytes"])
        lists = count(name -> src.cols[name] isa Jagged, names)
    else
        error("reduction supports original built-in nanoaod/cols sources only")
    end
    estimate = 16 * Int128(bytes) + 128 * Int128(n) * lists + 4096 * length(names) +
        8 * Int128(n) * (output_columns + 3) * variations
    estimate <= options["max_buffer_bytes"] || error("conservative reduced eager-buffer estimate exceeds max_buffer_bytes")
    return nothing
end
