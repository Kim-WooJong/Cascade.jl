"""Parse batch CLI commands; return 0 success, 1 runtime failure, 2 usage, 3 incomplete status."""
function batch_main(args)
    isempty(args) && (println(stderr, "usage: cascade batch plan ANALYSIS --workdir DIR | worker DIR ID | run DIR [--workers N] | status DIR | merge DIR [--through merge|systematics|fit|plot]"); return 2)
    command = args[1]
    command in ("plan", "worker", "run", "status", "merge") || return 2
    length(args) >= 2 || return 2
    try
        if command == "plan"
            _, opts = parse_cli(vcat(["run"], args[2:end]))
            batch_plan(opts)
        elseif command == "worker"
            length(args) == 3 || return 2
            batch_worker(args[2], args[3])
        elseif command == "run"
            length(args) in (2, 4) || return 2
            length(args) == 4 && args[3] != "--workers" && return 2
            workers = length(args) == 4 ? parse(Int, args[4]) : nothing
            batch_run(args[2]; workers)
        elseif command == "status"
            length(args) == 2 || return 2
            status = batch_status(args[2]); println(JSON3.write(status))
            return status["complete"] ? 0 : 3
        else
            length(args) in (2, 4) || return 2
            length(args) == 4 && args[3] != "--through" && return 2
            through = length(args) == 4 ? Symbol(args[4]) : :systematics
            global_steps = [:merge, :systematics, :fit, :plot]
            k = findfirst(==(through), global_steps); k === nothing && return 2
            println(batch_merge(args[2]; steps = global_steps[1:k]))
        end
        return 0
    catch e
        println(stderr, "cascade batch: ", sprint(showerror, e, catch_backtrace()))
        return 1
    end
end
