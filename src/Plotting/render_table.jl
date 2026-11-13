"""
    render_table(t::TextTable; format=:text) -> String

Render `t` as aligned plain text (`:text`), a Markdown pipe table
(`:markdown`) or a LaTeX `tabular` (`:latex`, wrapped in a `table` with
`\\caption` when the table has a caption). The first column is left-aligned,
the others right-aligned.
"""
function render_table(t::TextTable; format::Symbol=:text)
    format in (:text, :markdown, :latex) || throw(ArgumentError("format must be :text, :markdown or :latex"))
    header = [format_label(h, format) for h in t.header]
    rows = [[cell_string(c, format) for c in r] for r in t.rows]
    format == :text && return text_table(header, rows, t.rules, t.caption)
    format == :markdown && return markdown_table(header, rows, t.caption)
    return latex_table(header, rows, t.rules, t.caption)
end

cell_string(c::String, format::Symbol) = format_label(c, format)

function cell_string(c::NumberCell, format::Symbol)
    v = format_fixed(c.value, c.digits)
    c.kind == :value && return format == :latex && v != "n/a" ? "\$" * v * "\$" : v
    hi, lo = format_fixed(c.high, c.digits), format_fixed(c.low, c.digits)
    unc = if hi == "n/a" || lo == "n/a"
        "n/a"
    elseif hi == lo
        format == :latex ? "\\pm " * hi : "± " * hi
    else
        format == :latex ? "^{+" * hi * "}_{-" * lo * "}" : "+" * hi * " / -" * lo
    end
    text = c.kind == :uncertainty ? unc : v * " " * unc
    return format == :latex && unc != "n/a" ? "\$" * text * "\$" : text
end

function text_table(header, rows, rules, caption)
    widths = [maximum(textwidth, [header[j]; [r[j] for r in rows]]) for j in eachindex(header)]
    pad(s, j) = j == 1 ? rpad(s, widths[j]) : lpad(s, widths[j])
    line(cells) = rstrip(join((pad(c, j) for (j, c) in enumerate(cells)), "  "))
    rule = repeat("-", sum(widths) + 2 * (length(widths) - 1))
    out = String[]
    isempty(caption) || push!(out, caption)
    push!(out, line(header), rule)
    for (i, r) in enumerate(rows)
        push!(out, line(r))
        i in rules && i != length(rows) && push!(out, rule)
    end
    return join(out, "\n") * "\n"
end

function markdown_table(header, rows, caption)
    out = String[]
    isempty(caption) || push!(out, "**" * caption * "**", "")
    push!(out, "| " * join(header, " | ") * " |")
    push!(out, "|" * join((j == 1 ? ":---" : "---:" for j in eachindex(header)), "|") * "|")
    for r in rows
        push!(out, "| " * join(r, " | ") * " |")
    end
    return join(out, "\n") * "\n"
end

function latex_table(header, rows, rules, caption)
    out = String[]
    if !isempty(caption)
        push!(out, "\\begin{table}[htbp]", "\\centering", "\\caption{" * latex_label(caption) * "}")
    end
    push!(out, "\\begin{tabular}{l" * repeat("r", length(header) - 1) * "}", "\\hline")
    push!(out, join(header, " & ") * " \\\\", "\\hline")
    for (i, r) in enumerate(rows)
        push!(out, join(r, " & ") * " \\\\")
        (i in rules || i == length(rows)) && push!(out, "\\hline")
    end
    push!(out, "\\end{tabular}")
    isempty(caption) || push!(out, "\\end{table}")
    return join(out, "\n") * "\n"
end
