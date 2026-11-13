module CorrectionsTests

using Test
using Cascade
using Cascade.Corrections

include("helpers.jl")
include("test_json.jl")
include("test_formula.jl")
include("test_nodes.jl")
include("test_hashprng.jl")
include("test_api.jl")
include("test_errors.jl")
include("test_oracle_agreement.jl")

end # module
