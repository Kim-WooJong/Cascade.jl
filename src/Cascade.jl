"""
    Cascade

CMS NanoAOD analysis framework: selection, corrections, systematics,
histograms, profile-likelihood fit and plots. Each submodule lives in its
own folder; this file only includes them.
"""
module Cascade

include("Config/Config.jl")
include("IO/IO.jl")
include("Objects/Objects.jl")
include("Selection/Selection.jl")
include("Corrections/Corrections.jl")
include("Histograms/Histograms.jl")
include("Systematics/Systematics.jl")
include("Fit/Fit.jl")
include("Plotting/Plotting.jl")
include("Audit/Audit.jl")
include("Pipeline/Pipeline.jl")

end # module
