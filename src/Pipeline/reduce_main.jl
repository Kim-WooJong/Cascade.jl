"""Parse the distinct reduce CLI; malformed arguments exit2, failures exit1."""
function reduce_main(args)
    try
        isempty(args) && error("reduce needs analysis.toml and --output-dir UNUSED_DIR")
        values = Dict{String,String}()
        i = 2
        while i <= length(args)
            key = args[i]
            key in ("--output-dir", "--profile", "--samples", "--max-files") || error("unknown reduce option $key")
            i < length(args) && !haskey(values, key) || error("missing/duplicate reduce option $key")
            values[key] = args[i+1]; i += 2
        end
        haskey(values, "--output-dir") || error("reduce requires --output-dir")
        opts = RunOptions(args[1]; profile = get(values, "--profile", ""),
            samples = String.(split(get(values, "--samples", ""), ','; keepempty = false)),
            max_files = parse(Int, get(values, "--max-files", "0")))
        try
            result = reduce_analysis(opts; output_dir = values["--output-dir"])
            label = result["schema"] == 2 ? "logical_sources" : "files"
            records = result[result["schema"] == 2 ? "groups" : "files"]
            println(JSON3.write(Dict("id" => result["id"], label => length(records), "schema" => result["schema"])))
            return 0
        catch e
            println(stderr, "cascade reduce: ", sprint(showerror, e)); return 1
        end
    catch e
        println(stderr, "cascade reduce: ", sprint(showerror, e)); return 2
    end
end
