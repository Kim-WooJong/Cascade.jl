"""
    write_store(path, store::HistogramStore) -> path

Write the store as JSON (`format = "cascade-histograms"`, version 1). Float64
values use shortest round-trip printing, so `read_store` restores them exactly.
"""
function write_store(path::AbstractString, store::HistogramStore)
    payload = _store_payload(store)
    mkpath(dirname(abspath(path)))
    tmp = string(path, ".tmp.", getpid())
    open(tmp, "w") do io
        JSON3.write(io, payload)
    end
    mv(tmp, path; force = true)
    return path
end

# The exact JSON document written by write_store (also used by transport_store).
function _store_payload(store::HistogramStore)
    entries = [Dict("region" => k.region, "sample" => k.sample, "variation" => k.variation,
                    "variable" => k.variable, "edges" => store.hists[k].edges,
                    "sumw" => store.hists[k].sumw, "sumw2" => store.hists[k].sumw2) for k in keys(store)]
    return Dict("format" => "cascade-histograms", "version" => 1, "meta" => store.meta,
                "hists" => entries)
end

"""
    transport_store(store::HistogramStore) -> HistogramStore

In-memory equivalent of `read_store(write_store(path, store))`: serialise the same
JSON document to a String and parse it with the same reader. No file is touched.
Used where a no-checkpoint run must hand a consumer exactly what the persisted
route would have read back (metadata/numeric JSON semantics included).
"""
transport_store(store::HistogramStore) =
    _store_from_json(JSON3.read(JSON3.write(_store_payload(store))), "in-memory store")
