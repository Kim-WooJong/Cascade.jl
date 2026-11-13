"Read source header/normalization metadata, always closing opened handles."
function audit_file(s::SampleConfig, inventory, findings)
    record = copy(inventory)
    record["read_status"] = "failed"
    record["nevents"] = nothing
    record["normalization"] = Dict("status" => is_data(s) ? "not_applicable" : "missing", "value" => nothing)
    inventory["exists"] || return record
    src = nothing
    try
        src = open_source(s.format, record["path"]; options = get(s.raw, "source", Dict()))
        n = nevents(src)
        n isa Integer && !(n isa Bool) && n >= 0 || throw(ArgumentError("invalid Events entry count"))
        record["nevents"] = Int(n)
        record["physical_nfiles"] = src isa ReducedGroupSource ? length(src.meta["shards"]) : 1
        if src isa ReducedRNTupleSource || src isa ReducedGroupSource
            record["original_nevents"] = src.meta["original_nevents"]
            record["population"] = source_population(src)
            record["population_scope"] = "reduced Events; original normalization and cutflows preserved separately"
        end
        if is_mc(s)
            norm = normalization_metadata(src)
            if get(norm, "status", "invalid") == "available" &&
               !(get(norm, "value", nothing) isa Real && !(norm["value"] isa Bool) && isfinite(norm["value"]))
                norm = Dict{String,Any}("status" => "invalid", "value" => nothing,
                    "message" => "source supplied an invalid normalization metadata contract")
            end
            record["normalization"] = norm
            if norm["status"] == "unsupported"
                audit_finding!(findings, "unknown", "normalization_unverified", norm["message"]; sample = s.name, path = record["path"])
            elseif norm["status"] != "available"
                audit_finding!(findings, "error", "normalization_" * norm["status"], norm["message"]; sample = s.name, path = record["path"])
            elseif norm["value"] == 0
                audit_finding!(findings, "warning", "zero_file_sumw", "file generator sum is zero; sample aggregate is checked separately"; sample = s.name, path = record["path"])
            end
        end
        record["signature_after"] = file_signature(record["path"])
        if record["signature_after"] != record["signature"]
            audit_finding!(findings, "error", "input_changed_during_audit", "input size or mtime changed during metadata reading"; sample = s.name, path = record["path"])
        else
            record["read_status"] = "ok"
        end
    catch e
        record["read_error"] = sprint(showerror, e)
        audit_finding!(findings, "error", "source_read_failed", record["read_error"]; sample = s.name, path = record["path"])
    finally
        if src !== nothing
            try
                close_source(src)
            catch e
                record["read_status"] = "failed"
                audit_finding!(findings, "error", "source_close_failed", sprint(showerror, e); sample = s.name, path = record["path"])
            end
        end
    end
    return record
end
