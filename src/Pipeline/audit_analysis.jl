"""
    audit_analysis(opts::RunOptions; io=stdout) -> Dict

Audit fresh input inventories outside the pipeline step graph and write
`<workdir>/audit/report.json` and `report.md`, including failed checks.
"""
function audit_analysis(opts::RunOptions; io::Base.IO = stdout)
    cfg = load_analysis(opts.config; profile = opts.profile)
    opts.max_files == 0 || throw(ArgumentError("audit inspects complete discovered inventories; --max-files is unsupported"))
    report = Audit.audit_inputs(cfg; samples = opts.samples)
    report["provenance"]["code_hash"] = code_hash(["Audit", "Config", "IO"])
    report["provenance"]["profile"] = opts.profile
    work = abspath(isempty(opts.workdir) ? cfg.workdir : opts.workdir)
    paths = Audit.write_audit_report(report, joinpath(work, "audit"))
    counts = report["finding_counts"]
    println(io, "Audit: ", report["status"], " (errors=", counts["error"], ", warnings=", counts["warning"], ", unknowns=", counts["unknown"], ")")
    for p in paths; println(io, "Report: ", p); end
    return report
end
