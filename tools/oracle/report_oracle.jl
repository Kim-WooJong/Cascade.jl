# Agreement table and throughput for all oracle files of a directory.
"""
    report_oracle(io, dir)

Run compare_oracle and measure_throughput for every `*.oracle.json` in `dir`
and print one summary line per file. Returns the total number of mismatches.
"""
function report_oracle(io::IO, dir::AbstractString)
    total = 0
    for f in sort(filter(f -> endswith(f, ".oracle.json"), readdir(dir)))
        path = joinpath(dir, f)
        label = replace(f, ".oracle.json" => "")
        rows = compare_oracle(path; io = io)
        t = summarize_oracle(io, label, rows)
        total += t.mismatches
        tp = measure_throughput(path)
        println(io, rpad("", 34), " throughput: vectorized ", round(tp.rows / tp.vector_seconds / 1e6, digits = 2),
                " M evals/s, scalar ", round(tp.rows / tp.scalar_seconds / 1e6, digits = 2), " M evals/s (",
                tp.rows, " rows)")
        flush(io)
    end
    println(io, "TOTAL mismatches: ", total)
    return total
end
