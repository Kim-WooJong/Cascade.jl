"""Read this phase without caching partial columns or sharing a ROOT stream."""
function read_parallel_columns(scope::ColumnReadScope, names::AbstractVector{<:AbstractString};
                               needed::Union{Nothing,AbstractVector{Bool}} = nothing)
    unique_names = unique(names)
    length(unique_names) <= 1 && return read_columns(scope.original, names; needed)
    jobs = column_read_jobs(scope.original, unique_names, needed, scope.diagnostics)
    return read_column_jobs(scope, jobs, needed)
end
