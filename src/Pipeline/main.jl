"""
    main(args) -> Int

Command-line entry point (`bin/cascade`): parses `args` with `parse_cli`,
runs the pipeline and returns the process exit code.
"""
function main(args::AbstractVector{<:AbstractString})
    !isempty(args) && args[1] == "reduce" && return reduce_main(args[2:end])
    !isempty(args) && args[1] == "batch" && return batch_main(args[2:end])
    cmd, opts = try
        parse_cli(args)
    catch e
        println(stderr, "cascade: ", sprint(showerror, e))
        return 2
    end
    if cmd === :help
        println("""usage: cascade run <analysis.toml> [--steps a,b | --from STEP | --only STEP]
                         [--profile NAME] [--samples x,y] [--force] [--workdir DIR] [--max-files N]
                cascade check <analysis.toml> [--profile NAME]
                cascade audit <analysis.toml> [--profile NAME] [--samples x,y] [--workdir DIR]
                cascade reduce <analysis.toml> --output-dir UNUSED_DIR [--profile NAME] [--samples x,y] [--max-files N]
                cascade init <directory>
                steps: $(join(STEPS, " -> "))""")
        return 0
    end
    try
        if cmd === :check
            check_analysis(opts)
        elseif cmd === :audit
            report = audit_analysis(opts)
            return report["status"] == "fail" ? 1 : 0
        elseif cmd === :init
            init_analysis(opts.config)
        else
            run_pipeline(opts)
        end
        return 0
    catch e
        println(stderr, "cascade: error: ", sprint(showerror, e, catch_backtrace()))
        return 1
    end
end
