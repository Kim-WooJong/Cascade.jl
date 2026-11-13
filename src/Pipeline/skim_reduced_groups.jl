"""Persist a complete validated logical ledger and ordered physical chunk inventory."""
function skim_reduced_groups(ctx, sample, code)
    inventory = reduced_group_inventory(ctx.config, sample, ctx.options.max_files)
    isempty(inventory["groups"]) && error("no selected logical sources")
    key = artifact_key("skim-group", inventory, code)
    out = skim_path(ctx.workdir, sample.name)
    if !ctx.options.force && is_up_to_date(out, key)
        return false
    end
    mkpath(dirname(out)); write(out, JSON3.write(inventory))
    write_meta(out, key; step = "skim", sample = sample.name, nfiles = inventory["selected_nfiles"], physical_nfiles = inventory["physical_nfiles"])
    return true
end
