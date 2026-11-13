"""
    substitute_paths(s::AbstractString, paths::AbstractDict) -> String

Replace `\${name}` by `paths[name]` (recursively for nested references) and
expand a leading `~` to the home directory. `\${ENV:NAME}` reads an explicitly
named environment variable (missing or empty variables are errors). No shell
commands or general environment expansion are performed.
"""
function substitute_paths(s::AbstractString, paths::AbstractDict)
    out = String(s)
    for _ in 1:16
        m = match(r"\$\{(ENV:[A-Za-z_][A-Za-z0-9_]*|[A-Za-z0-9_]+)\}", out)
        m === nothing && break
        name = m.captures[1]
        value = if startswith(name, "ENV:")
            key = name[5:end]
            haskey(ENV, key) && !isempty(ENV[key]) ||
                throw(ArgumentError("undefined or empty environment path variable '$key'"))
            ENV[key]
        else
            haskey(paths, name) || throw(ArgumentError("undefined path variable \${$name} in \"$s\""))
            string(paths[name])
        end
        out = replace(out, "\${$name}" => value)
    end
    occursin("\${", out) && throw(ArgumentError("unresolved path variable in \"$s\""))
    return expanduser(out)
end
