"""
    output_column_index(cfg::AnalysisConfig) -> Dict{String,String}

Map from the normalised expression text of every `[output] columns` variable
to its event-table column (`"v:<name>"`). Used to find selection-time values
of object fields (e.g. `"muons.pt[1]"`) and sub-expressions.
"""
function output_column_index(cfg::AnalysisConfig)
    idx = Dict{String,String}()
    for v in cfg.output_columns
        idx[string(parse_expression(cfg.variables[v]))] = string("v:", v)
    end
    return idx
end
