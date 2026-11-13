"""
    expand_files(patterns) -> Vector{String}

Expand path patterns (`*`, `?` and `[...]` wildcards per path component; no
recursive `**`) into existing files. Patterns without wildcards are kept as
given. The result is de-duplicated and sorted by byte order, which fixes the
chunk order and therefore the floating-point summation order of merges.
"""
function expand_files(patterns)
    out = String[]
    for p in patterns
        if occursin(r"[*?\[]", p)
            append!(out, _glob(abspath(p)))
        else
            push!(out, p)
        end
    end
    return sort!(unique!(out))
end

function _glob(pattern::AbstractString)
    parts = split(pattern, '/'; keepempty = false)
    current = ["/"]
    for (k, part) in enumerate(parts)
        isdirpart = k < length(parts)
        next = String[]
        if occursin(r"[*?\[]", part)
            rx = _glob_regex(part)
            for d in current
                isdir(d) || continue
                for e in readdir(d)
                    (startswith(e, ".") && !startswith(part, ".")) && continue
                    occursin(rx, e) || continue
                    q = joinpath(d, e)
                    (isdirpart ? isdir(q) : ispath(q)) && push!(next, q)
                end
            end
        else
            for d in current
                q = joinpath(d, part)
                (isdirpart ? isdir(q) : ispath(q)) && push!(next, q)
            end
        end
        current = next
        isempty(current) && break
    end
    return filter(isfile, current)
end

function _glob_regex(part::AbstractString)
    io = IOBuffer()
    print(io, "^")
    inclass = false
    for c in part
        if inclass
            c == ']' && (inclass = false)
            print(io, c)
        elseif c == '*'
            print(io, "[^/]*")
        elseif c == '?'
            print(io, "[^/]")
        elseif c == '['
            inclass = true
            print(io, c)
        elseif c in raw".^$+(){}|\\"
            print(io, '\\', c)
        else
            print(io, c)
        end
    end
    print(io, "\$")
    return Regex(String(take!(io)))
end
