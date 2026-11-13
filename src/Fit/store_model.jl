"""
    HistModel(store::HistogramStore, fc::FitConfig) -> HistModel

Fit model built directly from a histogram store and a [`FitConfig`](@ref):
`HistModel(build_workspace(store, fc).workspace)` with the interpolation codes
of `fc`, so the fitted model is exactly the exported pyhf workspace.
"""
HistModel(store::HistogramStore, fc::FitConfig) =
    HistModel(build_workspace(store, fc).workspace; normsys_code = fc.normsys_code, histosys_code = fc.histosys_code)
