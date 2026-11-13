"""
    init_analysis(dir) -> String

Create `dir/analysis.toml` from the commented template. Never overwrite a file.
"""
function init_analysis(dir::AbstractString)
    dest = joinpath(abspath(dir), "analysis.toml")
    ispath(dest) && throw(ArgumentError("refusing to overwrite $dest"))
    mkpath(dirname(dest))
    cp(joinpath(@__DIR__, "..", "..", "analyses", "TEMPLATE.toml"), dest)
    println("Created ", dest)
    return dest
end
