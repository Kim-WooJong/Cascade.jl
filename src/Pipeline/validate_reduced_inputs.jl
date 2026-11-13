"""Preflight selected reduced groups/bytes/semantics and pinned built-in readers."""
function validate_reduced_inputs(cfg, samples = cfg.samples; max_files = 0, scope = nothing, verify_payloads = true)
    for s in samples
        s.format in ("reduced_rntuple", "reduced_rntuple_group") || continue
        isempty(HOOKS) && builtin_source_readers() || error("reduced analysis rejects custom hooks or replaced built-in readers")
        allowed = Dict("correct" => ("", "Cascade.Systematics.apply_corrections"), "systematics" => ("",), "fit" => ("",), "plot" => ("",))
        all(get(get(cfg.raw, "hooks", Dict()), k, "") in v for (k,v) in allowed) || error("unsupported reduced analysis hook")
        if s.format == "reduced_rntuple_group"
            reduced_group_inventory(cfg, s, max_files; scope, verify_payloads)
            continue
        end
        files = expand_files(s.files)
        validate_source_populations(s.format, files; options = get(s.raw, "source", Dict()))
        expected = reduced_contract(cfg, s)
        for path in files
            meta = read_reduced_metadata(path)
            meta["contract"] == expected || error("reduced retention/selection contract changed for $(s.name); re-export original inputs")
            meta["sample"] == s.name && meta["kind"] == String(s.kind) || error("reduced sample identity changed")
        end
    end
    return nothing
end
