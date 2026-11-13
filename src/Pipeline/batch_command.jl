"""Build a fresh Julia worker invocation using structured arguments, never a shell."""
function batch_command(work, task, threads)
    batch_load(work; task_id = task) # Reject changed launchers before starting any child.
    root = dirname(dirname(@__DIR__))
    entry = joinpath(root, "bin", "cascade.jl")
    return `$(Base.julia_cmd()) --startup-file=no --project=$root --threads=$threads $entry batch worker $work $task`
end
