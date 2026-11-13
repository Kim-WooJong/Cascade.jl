module TtbarIntegration
using Test, Cascade, TOML, JSON3, SHA, UnROOT, LinearAlgebra
using Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline
using Cascade.Selection: read_event_table, nrows
const P=Cascade.Pipeline
json(path)=P._jsdict(JSON3.read(read(path,String)))
writejson(path,value)=(mkpath(dirname(path));write(path,JSON3.write(value)))
const CORE=[:skim,:select,:correct,:histogram,:merge,:systematics]
include("bundle_root.jl")
include("prepare.jl")
include("verify_continuation.jl")
include("prepare_reuse.jl")
include("hash_probe.jl")
include("verify_inputs.jl")
include("verify_events.jl")
include("compare_outputs.jl")
include("fit_plot_case.jl")
include("compare_workspace.jl")
include("compare_fit_cases.jl")
include("fit_plot.jl")
include("accept_inventories.jl")
include("accept_reports.jl")
include("run_phase.jl")
end
