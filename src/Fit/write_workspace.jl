"""
    write_workspace(path, workspace::AbstractDict) -> path

Write a pyhf-style workspace (e.g. from [`build_workspace`](@ref)) as JSON,
readable by `pyhf.Workspace(json.load(...))` and by [`load_workspace`](@ref).
"""
function write_workspace(path::AbstractString, workspace::AbstractDict)
    mkpath(dirname(abspath(path)))
    write(path, JSON3.write(workspace))
    return path
end
