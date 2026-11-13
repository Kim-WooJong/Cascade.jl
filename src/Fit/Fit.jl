"""
    Cascade.Fit

Binned profile-likelihood fitting for HistFactory-like models
(channels x samples x bins) built from pyhf-style JSON workspaces or directly
from a `Histograms.HistogramStore` and the analysis `[fit]` section:
NLL, MLE fit with covariance, profile scans and intervals, test statistics,
asymptotic CLs limits and significance, pulls, impacts, pre/post-fit yields,
pyhf workspace export and JSON fit reports.
"""
module Fit

using LinearAlgebra
using ForwardDiff
using JSON3
using SpecialFunctions: loggamma, erfc
using ..Config: AnalysisConfig, SampleConfig, is_mc, is_data, require_counting_ready
using ..Histograms: HistogramStore, HistKey, NOMINAL, read_store
using ..Selection: EventTable, region_masks

include("ParameterInfo.jl")
include("HistModel.jl")
include("interpolation.jl")
include("load_workspace.jl")
include("build_model.jl")
include("expected_yields.jl")
include("Dataset.jl")
include("nll.jl")
include("newton_minimize.jl")
include("FitResult.jl")
include("fit_model.jl")
include("correlation_matrix.jl")
include("profile_scan.jl")
include("test_statistics.jl")
include("asimov_data.jl")
include("normal.jl")
include("hypotest.jl")
include("upper_limit.jl")
include("significance.jl")
include("pulls.jl")
include("impacts.jl")
include("yields.jl")
include("group_yields.jl")
include("profile_interval.jl")
include("FitChannel.jl")
include("FitSample.jl")
include("NormSysSpec.jl")
include("FitConfig.jl")
include("fit_config.jl")
include("channel_overlap_provenance.jl")
include("merge_channel_provenance.jl")
include("validate_channel_disjointness.jl")
include("build_workspace.jl")
include("store_model.jl")
include("write_workspace.jl")
include("counting_estimate.jl")
include("counting_measurement.jl")
include("counting_from_store.jl")
include("member_acceptance.jl")
include("json_safe.jl")
include("fit_report.jl")
include("report_model.jl")
include("report_result.jl")
include("fit_summary.jl")

export HistModel, ParameterInfo, Dataset, FitResult, HypotestResult, SignificanceResult, ChannelYields
export load_workspace, observed_data, expected_yields, expected_main, nll, newton_minimize
export histosys_delta, normsys_factor, code4_coefficients
export fit, correlation_matrix, profile_scan, tmu, qmu, qmu_tilde, q0, asimov_data
export hypotest, upper_limit, significance, pulls, impacts
export yields_with_uncertainty, prefit_yields, postfit_yields, group_yields, profile_interval
export FitChannel, FitSample, NormSysSpec, FitConfig, fit_config, build_workspace, write_workspace
export channel_overlap_provenance, merge_channel_provenance!, validate_channel_disjointness
export counting_from_store, counting_measurement, member_acceptance, counting_estimate, json_safe, fit_report, report_model, report_result, fit_summary

end
