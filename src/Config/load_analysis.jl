"""
    load_analysis(path::AbstractString; validate = true) -> AnalysisConfig

Read and validate an analysis TOML file. Relative paths inside the file are
resolved against the directory of the file.
"""
function load_analysis(path::AbstractString; validate::Bool = true, profile::AbstractString = "")
    p = abspath(path)
    raw = TOML.parsefile(p)
    validate && validate_keys(raw)
    cfg = parse_analysis(raw; path = p, dir = dirname(p), profile)
    validate && validate_analysis(cfg)
    return cfg
end
