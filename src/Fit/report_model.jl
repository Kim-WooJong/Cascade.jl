"""
    report_model(report::AbstractDict) -> HistModel

Rebuild the fitted model of a [`fit_report`](@ref) dictionary (also after a
JSON round trip) from its embedded pyhf workspace and interpolation codes.
"""
function report_model(report::AbstractDict)
    o = get(report, "options", Dict{String,Any}())
    return HistModel(report["workspace"]; normsys_code = Symbol(get(o, "normsys_code", "code4")),
                     histosys_code = Symbol(get(o, "histosys_code", "code4p")))
end
