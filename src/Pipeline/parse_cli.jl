"""
    parse_cli(args) -> (command::Symbol, options::Union{RunOptions,Nothing})

Parse `run <analysis.toml> [--steps a,b] [--from s] [--only s]
[--samples x,y] [--force] [--workdir d] [--max-files n]`. `--steps`, `--from`
and `--only` are mutually exclusive. Returns `(:help, nothing)` for help.
"""
function parse_cli(args::AbstractVector{<:AbstractString})
    a = String.(args)
    (isempty(a) || a[1] in ("-h", "--help", "help")) && return (:help, nothing)
    a[1] in ("run", "check", "init", "audit") || throw(ArgumentError("unknown command '$(a[1])' (expected run, check, init or audit)"))
    length(a) >= 2 || throw(ArgumentError("$(a[1]) needs $(a[1] == "init" ? "a directory" : "an analysis TOML file")"))
    config = a[2]
    opts = Dict{String,String}()
    flags = Set{String}()
    k = 3
    while k <= length(a)
        x = a[k]
        startswith(x, "--") || throw(ArgumentError("unexpected argument '$x'"))
        if occursin('=', x)
            name, val = split(x[3:end], '='; limit = 2)
            opts[name] = val
        elseif x == "--force"
            push!(flags, "force")
        else
            k < length(a) || throw(ArgumentError("option $x needs a value"))
            opts[x[3:end]] = a[k+1]
            k += 1
        end
        k += 1
    end
    for name in keys(opts)
        name in ("steps", "from", "only", "samples", "workdir", "max-files", "profile") ||
            throw(ArgumentError("unknown option --$name"))
    end
    if a[1] != "run"
        allowed = a[1] == "check" ? ("profile",) : a[1] == "audit" ? ("profile", "samples", "workdir") : ()
        all(k -> k in allowed, keys(opts)) && isempty(flags) || throw(ArgumentError("unsupported option for $(a[1])"))
    end
    steps = plan_steps(; steps = get(opts, "steps", nothing), from = get(opts, "from", nothing),
                       only = get(opts, "only", nothing))
    samples = haskey(opts, "samples") ? String.(split(opts["samples"], ','; keepempty = false)) : String[]
    return (Symbol(a[1]), RunOptions(; config, steps, samples, profile = get(opts, "profile", ""), force = "force" in flags,
                             workdir = get(opts, "workdir", ""),
                             max_files = parse(Int, get(opts, "max-files", "0"))))
end
