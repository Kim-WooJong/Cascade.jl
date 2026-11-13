const _PLOT_KEYS = ("formats", "lumi_label", "energy", "extra", "regions", "variables", "logy", "region_labels",
                   "labels", "colors", "groups", "data", "prefit", "postfit", "tables", "cutflow", "impacts",
                   "band_normsys", "max_impacts")

"""
    plot_options(cfg::AnalysisConfig; lumi_pb=cfg.lumi_pb) -> PlotOptions

Read the optional `[plot]` section (all keys optional):

```toml
[plot]
formats = ["png", "pdf"]           # (both)
lumi_label = "1.21 fb^{-1}"        # (from analysis.lumi_pb)
energy = "13.6 TeV"
extra = "Preliminary"
regions = []                       # (all regions)
variables = []                     # (all histograms)
logy = ["lep_pt"]                  # also drawn with log y
region_labels = { emu_ge1j = "e#mu, #geq1 jet" }
labels = { ttbar = "t#bar{t}" }    # display label per sample group
colors = { ttbar = "#C5001A" }
data = ["MuonEG"]                  # (all data samples)
prefit = true; postfit = true; tables = true; cutflow = true; impacts = true
band_normsys = true                # [fit] normsys in the prefit band
max_impacts = 30

[[plot.groups]]                    # explicit stack, bottom first (default: sample groups)
label = "t#bar{t}"
color = "#C5001A"
samples = ["TTto2L2Nu", "TTtoLNu2Q"]
```
"""
function plot_options(cfg::AnalysisConfig; lumi_pb::Real = cfg.lumi_pb)
    p = get(cfg.raw, "plot", Dict{String,Any}())
    for k in keys(p)
        String(k) in _PLOT_KEYS || throw(ArgumentError("unknown [plot] key '$k'"))
    end
    fs = Symbol.(get(p, "formats", ["png", "pdf"]))
    formats = Set(fs) == Set([:png, :pdf]) ? :both : length(fs) == 1 && only(fs) in (:png, :pdf) ? only(fs) :
              throw(ArgumentError("[plot] formats must be [\"png\"], [\"pdf\"] or both"))
    lumi = haskey(p, "lumi_label") ? String(p["lumi_label"]) : _lumi_label(lumi_pb)
    sdict(k) = Dict{String,String}(String(a) => String(b) for (a, b) in get(p, k, Dict{String,Any}()))
    return PlotOptions(formats, lumi, String(get(p, "energy", "13.6 TeV")), String(get(p, "extra", "Preliminary")),
                       String.(get(p, "regions", String[])), String.(get(p, "variables", String[])),
                       String.(get(p, "logy", String[])), sdict("region_labels"), sdict("labels"), sdict("colors"),
                       haskey(p, "groups") ? collect(Any, p["groups"]) : nothing,
                       haskey(p, "data") ? String.(p["data"]) : nothing,
                       Bool(get(p, "prefit", true)), Bool(get(p, "postfit", true)), Bool(get(p, "tables", true)),
                       Bool(get(p, "cutflow", true)), Bool(get(p, "impacts", true)),
                       Bool(get(p, "band_normsys", true)), Int(get(p, "max_impacts", 30)))
end

function _lumi_label(lumi_pb::Real)
    fb = lumi_pb / 1000
    return (fb >= 10 ? string(round(fb; digits = 1)) : string(round(fb; digits = 2))) * " fb^{-1}"
end
