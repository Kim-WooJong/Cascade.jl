using Test
using Cascade
using Cascade.Plotting
using ROOTPlots: ROOTPlots, Hist1D
using TOML: TOML

# Entry file: includes only. Rendering tests need native ROOT; real-data tests need CASCADE_REAL_DATA=1.
include("fixtures.jl")
include("binned_hist_tests.jl")
include("templates_tests.jl")
include("config_tests.jl")
include("nuisance_tests.jl")
include("band_tests.jl")
include("poisson_tests.jl")
include("comparison_tests.jl")
include("postfit_tests.jl")
include("fit_adapter_tests.jl")
include("table_tests.jl")
include("cutflow_tests.jl")
include("render_tests.jl")
include("real_data_tests.jl")
include("luminosity_label_tests.jl")
