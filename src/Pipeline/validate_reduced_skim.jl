"""Bind persisted skims to current selected reduced paths and verified bundle bytes.

Called before every downstream stage, including cached returns and direct step
APIs. This checks input binding only: it does not automatically refresh arbitrary
omitted numerical stages after otherwise compatible configuration edits.
"""
function validate_reduced_skim(ctx::StepContext)
    for sample in ctx.samples
        sample.format in ("reduced_rntuple", "reduced_rntuple_group") && continue
        path = skim_path(ctx.workdir, sample.name)
        if isfile(path)
            skim = read_skim(ctx.workdir, sample.name)
            any(e -> get(get(e, "signature", Dict()), "format", "") in ("reduced_rntuple", "reduced_rntuple_group"), skim["files"]) &&
                error("reduced skim input binding changed for $(sample.name): reader format differs; rerun skim and required upstream stages")
        end
    end
    reduced = [s for s in ctx.samples if s.format in ("reduced_rntuple", "reduced_rntuple_group")]
    isempty(reduced) && return nothing
    validate_reduced_inputs(ctx.config, reduced; max_files = ctx.options.max_files, scope = ctx.input_scope, verify_payloads = ctx.input_scope === nothing)
    for sample in reduced
        if sample.format == "reduced_rntuple_group"
            ctx.input_scope === nothing || ctx.step in (:select, :correct, :histogram) || error("worker scope is not a complete logical normalization certificate")
            current = reduced_group_inventory(ctx.config, sample, ctx.options.max_files; scope = ctx.input_scope, verify_payloads = false)
            isfile(skim_path(ctx.workdir, sample.name)) || error("reduced skim missing; rerun skim and required upstream stages")
            persisted = read_skim(ctx.workdir, sample.name)
            get(persisted, "schema", 1) == 2 && batch_hash(current["groups"]) == batch_hash(get(persisted, "groups", nothing)) &&
                batch_hash(current["files"]) == batch_hash(persisted["files"]) || error("reduced skim input binding changed; rerun skim and required upstream stages")
            continue
        end
        sample.format == "reduced_rntuple" || continue
        fail(message) = error("reduced skim input binding changed for $(sample.name): $message; rerun skim and required upstream stages")
        files = expand_files(sample.files)
        limit = ctx.options.max_files
        limit >= 0 || fail("negative max_files")
        limit > 0 && length(files) > limit && (files = files[1:limit])
        path = skim_path(ctx.workdir, sample.name)
        isfile(path) || fail("persisted skim is missing")
        skim = read_skim(ctx.workdir, sample.name)
        get(skim, "sample", nothing) == sample.name && get(skim, "kind", nothing) == String(sample.kind) || fail("sample identity mismatch")
        entries = skim["files"]
        [String(e["path"]) for e in entries] == files || fail("selected file inventory differs")
        for (file, entry) in zip(files, entries)
            meta = read_reduced_metadata(file) # Current paths only; never follow stale skim paths.
            expected = merge(file_signature(file), Dict{String,Any}("format" => "reduced_rntuple"))
            canonical_hash(entry["signature"]) == canonical_hash(expected) || fail("payload/sidecar/manifest signature differs")
            meta["contract"] == reduced_contract(ctx.config, sample) || fail("retention contract differs")
            entry["nevents"] == meta["retained_nevents"] && entry["gen_weight_sum"] == (is_mc(sample) ? meta["normalization"]["value"] : 0.0) || fail("population counts or normalization differ")
            haskey(entry, "population") && population_identity(entry["population"]) == population_identity(meta["population"]) || fail("original ownership differs")
        end
    end
    return nothing
end
