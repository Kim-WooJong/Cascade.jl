"""
    write_table(t::TextTable, stem; formats=(:text, :markdown, :latex)) -> Vector{String}

Write `t` rendered in each format to `stem.txt`, `stem.md` and `stem.tex`;
returns the written paths.
"""
function write_table(t::TextTable, stem::AbstractString; formats = (:text, :markdown, :latex))
    ext = Dict(:text => ".txt", :markdown => ".md", :latex => ".tex")
    mkpath(dirname(abspath(stem)))
    files = String[]
    for f in formats
        path = stem * ext[f]
        write(path, render_table(t; format = f))
        push!(files, path)
    end
    return files
end
