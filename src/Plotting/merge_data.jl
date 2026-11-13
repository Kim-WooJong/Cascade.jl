"""
    merge_data(templates, config::StackConfig; allow_missing=false) -> BinnedHist

Observed histogram: sum of the nominal histograms of the data samples of
`config` (variations of data samples are ignored).
"""
function merge_data(templates::AbstractDict{<:AbstractString,SampleTemplates}, config::StackConfig;
                    allow_missing::Bool=false)
    isempty(config.data) && throw(ArgumentError("the plotting configuration lists no data sample"))
    return merge_samples(templates, config.data; name="Data", allow_missing).nominal
end
