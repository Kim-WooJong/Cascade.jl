"""Close every successfully opened owned slot, including after partial setup failure."""
function with_column_read_scope(run, scope::ColumnReadScope)
    try
        result = run(scope)
        scope.verify()
        return result
    finally
        # read_column_jobs joins every worker before returning or throwing.
        errors = Any[]
        for slot in scope.slots[2:end]
            try
                scope.closer(slot)
            catch e
                push!(errors, e)
            finally
                scope.diagnostics["extra_closes"] += 1
            end
        end
        resize!(scope.slots, 1)
        isempty(errors) || throw(first(errors))
    end
end
