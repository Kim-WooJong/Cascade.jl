"""
    write_audit_report(report, dir) -> Vector{String}

Write machine-readable JSON and a human Markdown summary even when checks fail.
The report labels unknown completeness and exposure; it does not certify inputs.
"""
function write_audit_report(report::AbstractDict, dir::AbstractString)
    mkpath(dir)
    json = joinpath(dir, "report.json"); markdown = joinpath(dir, "report.md")
    write(json, JSON3.write(report))
    # Escape user-controlled labels before inserting them into Markdown tables.
    cell(x) = replace(x === nothing ? "not measured" : string(x), "|" => "\\|", "\n" => " ", "\r" => " ", "`" => "'")
    open(markdown, "w") do io
        println(io, "# Input audit: ", cell(report["analysis"]))
        println(io, "\nStatus: **", report["status"], "** — ", report["status_scope"], ".")
        println(io, "\nFinding counts: ", cell(report["finding_counts"]), ". Metadata sample scope: ", join(cell.(report["scope"]["metadata_samples"]), ", "), ".")
        println(io, "\n| Sample | Discovered files | Readable files | Events | Signed MC sum | Inventory completeness |")
        println(io, "|---|---:|---:|---:|---:|---|")
        for name in report["order"]
            s = report["samples"][name]
            println(io, "| ", join(cell.([name, s["discovered_nfiles"], s["readable_nfiles"], s["nevents"], s["gen_weight_sum"], s["inventory_completeness"]]), " | "), " |")
        end
        println(io, "\n## Declared sample provenance\n")
        println(io, "Values below are declarations, not independently verified calibrations. Missing values are unspecified.")
        println(io, "\n| Sample | Dataset | Era | Campaign | Cross-section source | Inventory source |")
        println(io, "|---|---|---|---|---|---|")
        for name in report["order"]
            s = report["samples"][name]; m = s["metadata"]
            vals = [name, get(m, "dataset", "unspecified"), get(m, "era", "unspecified"), get(m, "campaign", "unspecified"), get(m, "xsec_source", "unspecified"), s["inventory_source"]]
            println(io, "| ", join(cell.(vals), " | "), " |")
        end
        for name in report["order"]
            s = report["samples"][name]
            for (key, label) in (("missing_expected_files", "Missing expected paths"), ("unexpected_files", "Unexpected paths"))
                paths = get(s, key, String[])
                isempty(paths) || println(io, "\n", cell(name), " — ", label, " (", length(paths), "): ", join(cell.(first(paths, min(20, length(paths)))), ", "), length(paths) > 20 ? " (first 20; full list in JSON)" : "")
            end
        end
        println(io, "\nActual data exposure: **unknown**. ", report["exposure"]["scope"], ".")
        println(io, "\nEvent-ID and copied-content duplication: not assessed. Files were not altered or deduplicated by the audit.")
        println(io, "\n## Findings\n")
        for f in report["findings"]
            println(io, "- **", f["severity"], " / ", f["code"], "** [", cell(f["sample"]), "] ", cell(f["message"]),
                isempty(f["path"]) ? "" : " — " * cell(f["path"]))
            for key in ("observed", "expected")
                f[key] === nothing && continue
                detail = cell(JSON3.write(f[key]))
                println(io, "  - ", key, ": ", first(detail, min(length(detail), 1000)), length(detail) > 1000 ? " … (full value in JSON)" : "")
            end
        end
    end
    return [json, markdown]
end
