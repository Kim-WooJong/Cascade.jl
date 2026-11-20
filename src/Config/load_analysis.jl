"""
    load_analysis(path; validate=true, profile="") -> AnalysisConfig

Read an entry TOML and explicit includes. All relative analysis asset paths
retain the entry directory, regardless of which fragment declares them.
"""
function load_analysis(path::AbstractString; validate::Bool = true, profile::AbstractString = "")
    return load_analysis_source(path; validate, profile).config
end

"Load typed configuration and its exact verified TOML source snapshot together."
function load_analysis_source(path::AbstractString; validate::Bool = true, profile::AbstractString = "")
    p = abspath(path)
    source = read_analysis_source(p; check_keys = validate)
    cfg = parse_analysis(source.raw; path = p, dir = dirname(p), profile)
    validate && validate_analysis(cfg)
    verify_config_sources(source.provenance)
    return (; config = cfg, provenance = source.provenance)
end
