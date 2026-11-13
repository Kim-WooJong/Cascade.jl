"Sum a union of LS pairs in deterministic run/LS order, never per file or PD."
function lumisection_luminosity(coverage, table)
    pairs = sort!(unique([(Int(p[1]), Int(p[2])) for p in coverage]))
    total = 0.0
    for p in pairs
        haskey(table, p) || throw(ArgumentError("luminosity table missing certified observed run/LS $(p[1])/$(p[2])"))
        total += table[p]
    end
    return total
end
