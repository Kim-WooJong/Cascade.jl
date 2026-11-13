"""Reject repeated original normalization populations within one sample only.

Original physical identity needs no Events materialization. Derivatives use their
verified metadata even if accidentally listed alongside an original source.
"""
function validate_source_populations(format, paths; options = Dict())
    format in ("nanoaod", "cols", "reduced_rntuple", "reduced_rntuple_group") || return nothing
    seen = Set{String}()
    for path in paths
        population = if format in ("reduced_rntuple", "reduced_rntuple_group") || endswith(path, ".source.json") || isfile(path * ".cascade.json")
            read_reduced_metadata(path)["population"]
        else
            st = stat(path)
            Dict("realpath" => realpath(path), "device" => string(st.device), "inode" => string(st.inode))
        end
        key = population_identity(population)
        key in seen && error("duplicate original normalization population in sample: $path")
        push!(seen, key)
    end
    return nothing
end
