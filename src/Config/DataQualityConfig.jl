"""
    DataQualityConfig

Run range and certified-luminosity (Golden JSON) mask for data. `golden_json`
is an absolute path or `""` (no lumi-section mask). Branch aliases permit
nonstandard input naming without editing the selection implementation.
"""
struct DataQualityConfig
    run_min::Int
    run_max::Int
    golden_json::String
    run_branch::String
    lumi_branch::String
end

DataQualityConfig() = DataQualityConfig(typemin(Int), typemax(Int), "")
DataQualityConfig(run_min::Int, run_max::Int, golden_json::String) =
    DataQualityConfig(run_min, run_max, golden_json, "run", "luminosityBlock")
