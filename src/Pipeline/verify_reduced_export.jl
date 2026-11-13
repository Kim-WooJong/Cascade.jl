"""Require fresh-process generated-config/reader validation before publication."""
function verify_reduced_export(stage, final)
    root = dirname(dirname(@__DIR__))
    entry = joinpath(root, "bin", "validate_reduced_export.jl")
    config = joinpath(stage, "analysis.toml")
    command = Cmd(vcat(Base.julia_cmd().exec, ["--startup-file=no", "--project=" * root,
        "--threads=1", entry, config, String(stage), String(final)]))
    run(command)
    return nothing
end
