"""
    Cascade.Objects

Physics-object building blocks used by compiled selections: kinematics
(`deltaR`, `mass_massless`), per-event object filtering, overlap removal and
ordering. All functions are allocation-free on preallocated index buffers.
"""
module Objects

include("deltaR.jl")
include("mass_massless.jl")
include("mass_massive.jl")
include("pair_pt.jl")
include("select_objects.jl")
include("isolated_from.jl")
include("sort_objects.jl")

export deltaR, mass_massless, mass_massive, pair_pt, select_objects!, isolated_from, sort_objects!

end # module
