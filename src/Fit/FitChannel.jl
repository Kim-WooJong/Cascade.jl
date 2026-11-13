"""
    FitChannel(name, region, variable)

One fit channel: the histograms of `variable` in `region` of a
`HistogramStore`. `name` is the channel name in the workspace (default
`"<region>_<variable>"`).
"""
struct FitChannel
    name::String
    region::String
    variable::String
end
