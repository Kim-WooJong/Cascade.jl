"""
    cms_panel_spec(xlabel; ylabel="Events", lumi="", energy="13.6 TeV", extra="Preliminary",
                   annotation="", logy=false, logx=false, ymin=nothing, ymax=nothing,
                   ratio_limits=(0.5, 1.5), bin_labels=nothing) -> ROOTPlots.PanelSpec

Data/MC panel specification in the CMS style (`style=:CMS`): "CMS" with the
`extra` text inside the frame, `"lumi (energy)"` above the frame on the right,
and `annotation` (e.g. the region) as a line below the label. `logy` sets the
upper pad to a log scale; when `logy` and `ymin === nothing` ROOTPlots chooses
the range from the positive drawable values. `bin_labels` labels the x bins
(e.g. cutflow stages). Labels use ROOT TLatex.
"""
function cms_panel_spec(xlabel::AbstractString; ylabel::AbstractString="Events", lumi::AbstractString="",
                        energy::AbstractString="13.6 TeV", extra::AbstractString="Preliminary",
                        annotation::AbstractString="", logy::Bool=false, logx::Bool=false,
                        ymin=nothing, ymax=nothing, ratio_limits=(0.5, 1.5), bin_labels=nothing)
    xaxis = bin_labels === nothing ? AxisStyle() : AxisStyle(bin_labels=collect(String.(bin_labels)))
    return PanelSpec(xlabel; ylabel, annotation, lumi, logx, logy, ymin, ymax,
                     ratio_limits=(Float64(ratio_limits[1]), Float64(ratio_limits[2])), xaxis,
                     style=:CMS, cms_label=(extra=String(extra), lumi=String(lumi), energy=String(energy)))
end
