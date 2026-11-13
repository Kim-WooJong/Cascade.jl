"""
    TextTable(header, rows; rules=Int[], caption="")

Format-neutral table: `header` and each row hold `String` labels (ROOT TLatex
allowed, e.g. `"t#bar{t}"`) or [`NumberCell`](@ref)s. `rules` lists row
indices after which a horizontal rule is drawn. Render with
[`render_table`](@ref) as plain text, Markdown or LaTeX; `show` prints text.
"""
struct TextTable
    header::Vector{String}
    rows::Vector{Vector{Union{String,NumberCell}}}
    rules::Vector{Int}
    caption::String

    function TextTable(header::AbstractVector, rows::AbstractVector; rules=Int[], caption::AbstractString="")
        h = String.(header)
        rs = Vector{Vector{Union{String,NumberCell}}}()
        for r in rows
            length(r) == length(h) || throw(ArgumentError("row length $(length(r)) differs from header length $(length(h))"))
            push!(rs, Union{String,NumberCell}[c isa NumberCell ? c : String(c) for c in r])
        end
        all(i -> 1 <= i <= length(rs), rules) || throw(ArgumentError("rule index outside the table"))
        return new(h, rs, sort!(unique(Int.(rules))), String(caption))
    end
end

Base.show(io::IO, ::MIME"text/plain", t::TextTable) = print(io, render_table(t; format=:text))
