"""Annotate reduced selection output without changing local correction row indices."""
function attach_reduced_provenance!(results, src)
    src isa ReducedRNTupleSource || src isa ReducedShardSource || return results
    metadata = src isa ReducedShardSource ? src.meta["group"] : src.meta
    original = read_columns(src, ["cascade_source_entry"])["cascade_source_entry"]
    for (_, (table, _)) in results
        table.columns["source_entry"] = original[table["entry"]]
        push!(table.order, "source_entry")
        table.meta["population"] = deepcopy(metadata["population"])
        table.meta["cutflow_population"] = "reduced retained events; not original all-event prefixes"
        if src isa ReducedShardSource
            table.meta["logical_group_id"] = metadata["group_id"]
            table.meta["logical_descriptor"] = metadata["descriptor_path"]
        else
            table.meta["original_cutflows"] = deepcopy(metadata["original_cutflows"])
        end
        table.meta["original_nevents"] = metadata["original_nevents"]
        table.meta["original_source_signature"] = deepcopy(metadata["source_signature"])
        table.meta["retention_contract"] = metadata["contract"]
    end
    return results
end
