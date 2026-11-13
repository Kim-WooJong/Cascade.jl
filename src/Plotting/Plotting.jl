"""
    Cascade.Plotting

Physics plots and tables on top of ROOTPlots.jl: data/MC stacks with ratio
panels, prefit (stat ⊕ syst from named variations) and postfit uncertainty
bands, CMS labels, configurable sample groups and colours, yield,
uncertainty-breakdown and cutflow tables (text/Markdown/LaTeX), cutflow plots
and pull/impact ranking plots. Histograms are `Cascade.Histograms.BinnedHist`
values (re-exported; built from plain arrays with [`binned_hist`](@ref) or
taken from a store with [`store_templates`](@ref)); ROOTPlots `Hist1D` is
accepted through adapters. [`plot_analysis`](@ref) produces every output of an
analysis from its merged store and fit report (the default pipeline plot hook).
"""
module Plotting

using TOML: TOML
using ROOTPlots: ROOTPlots, Hist1D, Component, BinErrors, PanelSpec, AxisStyle, GraphSpec, HistStack,
                 Comparison, comparison, render_root, GraphSeries, GraphStyle, PlotLine, PlotText, CanvasStyle,
                 PlotPanel, PlotFigure
using ..Config: AnalysisConfig, is_mc, is_data
using ..Histograms: BinnedHist, HistogramStore, HistKey, NOMINAL, store_axis
using ..Fit: HistModel, FitResult, group_yields, fit_config, report_model, report_result

export BinnedHist, binned_hist, hist_sum, hist_scale, total_yield, to_hist1d,
       SampleTemplates, collect_templates, store_templates, merge_samples, add_norm_variations,
       Nuisance, infer_nuisances, nuisance_shifts, UncertaintyBand, uncertainty_band,
       SampleGroup, StackConfig, stack_config, group_templates, merge_data, present_stack,
       FitYields, fit_yields, postfit_groups, postfit_band,
       poisson_errors, stack_comparison, auto_ylimits, cms_panel_spec, plot_prefit, plot_postfit,
       NumberCell, value_cell, uncertainty_cell, TextTable, format_label, format_fixed, render_table, write_table,
       yield_table, uncertainty_table,
       Cutflow, group_cutflow, cutflow_table, plot_cutflow,
       impact_rows, plot_impacts,
       PlotOptions, plot_options, analysis_stack_config, analysis_cutflow, prefit_outputs, postfit_outputs,
       plot_analysis

include("binned_hist.jl")
include("hist_sum.jl")
include("hist_scale.jl")
include("total_yield.jl")
include("hist_adapters.jl")
include("SampleTemplates.jl")
include("collect_templates.jl")
include("store_templates.jl")
include("merge_samples.jl")
include("add_norm_variations.jl")
include("Nuisance.jl")
include("infer_nuisances.jl")
include("nuisance_shifts.jl")
include("UncertaintyBand.jl")
include("uncertainty_band.jl")
include("SampleGroup.jl")
include("StackConfig.jl")
include("stack_config.jl")
include("present_stack.jl")
include("group_templates.jl")
include("merge_data.jl")
include("FitYields.jl")
include("fit_yields.jl")
include("postfit_groups.jl")
include("postfit_band.jl")
include("poisson_errors.jl")
include("stack_comparison.jl")
include("auto_ylimits.jl")
include("cms_panel_spec.jl")
include("plot_prefit.jl")
include("plot_postfit.jl")
include("NumberCell.jl")
include("TextTable.jl")
include("format_label.jl")
include("format_fixed.jl")
include("render_table.jl")
include("write_table.jl")
include("yield_table.jl")
include("uncertainty_table.jl")
include("Cutflow.jl")
include("group_cutflow.jl")
include("cutflow_table.jl")
include("plot_cutflow.jl")
include("impact_rows.jl")
include("plot_impacts.jl")
include("PlotOptions.jl")
include("plot_options.jl")
include("analysis_stack_config.jl")
include("analysis_cutflow.jl")
include("prefit_outputs.jl")
include("postfit_outputs.jl")
include("plot_analysis.jl")

end # module
