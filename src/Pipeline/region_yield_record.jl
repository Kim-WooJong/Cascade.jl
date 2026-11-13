"""
    region_yield_record(n, sumw, norm; histogram_integral=nothing, histogram_variable="")

Unambiguously distinguish selected-event cutflow accounting from a histogram's
stored-bin weighted fills. The legacy n/sumw/yield/hist_yield keys remain aliases.
A histogram may have multiple fills per event, extra `when` selection, or
underflow drops and overflow folding; its integral is not an exact selected-event yield.
"""
function region_yield_record(n, sumw, norm; histogram_integral = nothing, histogram_variable = "")
    y = norm * sumw
    return Dict{String,Any}("selected_event_count" => n, "cutflow_sumw_raw" => sumw,
        "cutflow_yield" => y, "histogram_integral" => histogram_integral,
        "histogram_variable" => histogram_variable,
        "n" => n, "sumw" => sumw, "yield" => y, "hist_yield" => histogram_integral)
end
