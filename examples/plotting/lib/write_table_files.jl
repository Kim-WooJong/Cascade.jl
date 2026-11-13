"""
    write_table_files(table, stem) -> Vector{String}

Write `table` as `stem.txt`, `stem.md` and `stem.tex`, print the text form,
and return the paths.
"""
function write_table_files(table::TextTable, stem::AbstractString)
    paths = String[]
    for (format, ext) in ((:text, ".txt"), (:markdown, ".md"), (:latex, ".tex"))
        write(stem * ext, render_table(table; format))
        push!(paths, stem * ext)
    end
    println(render_table(table))
    return paths
end
