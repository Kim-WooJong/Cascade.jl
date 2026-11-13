# Standalone fixtures own Main and must not share bindings with package tests.
function isolated_area_command(entry::AbstractString)
    project = Base.active_project()
    project === nothing && error("isolated tests require an active project")
    isfile(entry) || throw(ArgumentError("test entry does not exist: $entry"))
    # Base.julia_cmd propagates compiler/bounds/compiled-module/image options.
    # Thread count and active Pkg.test environment need explicit propagation.
    # Consume the entry argument so fixture code sees no synthetic ARGS[1].
    bootstrap = "using Test; include(popfirst!(ARGS))"
    return `$(Base.julia_cmd()) --startup-file=no --threads=$(Threads.nthreads()) --project=$(dirname(project)) -e $bootstrap $(abspath(entry))`
end
