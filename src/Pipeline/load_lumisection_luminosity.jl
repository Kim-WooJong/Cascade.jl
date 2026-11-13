"Explicit JSON table: {\"run\": {\"lumisection\": luminosity_in_pb_inverse}}."
function load_lumisection_luminosity(path::AbstractString)
    d = JSON3.read(read(path, String))
    table = Dict{Tuple{Int,Int},Float64}()
    for (run, sections) in pairs(d)
        r = tryparse(Int, String(run))
        r === nothing && throw(ArgumentError("luminosity table run must be an integer: $run"))
        r > 0 || throw(ArgumentError("luminosity table run must be positive: $run"))
        sections isa JSON3.Object || throw(ArgumentError("luminosity table run $run must map LS keys to pb^-1 values"))
        for (ls, value) in pairs(sections)
            l = tryparse(Int, String(ls))
            (l !== nothing && l > 0) || throw(ArgumentError("luminosity table LS must be positive integer: $ls"))
            value isa Real && !(value isa Bool) || throw(ArgumentError("luminosity table $run/$ls must be numeric"))
            v = Float64(value)
            isfinite(v) && v >= 0 || throw(ArgumentError("luminosity table $run/$ls must be finite and nonnegative"))
            key = (r, l)
            haskey(table, key) && throw(ArgumentError("duplicate numeric run/LS in luminosity table: $run/$ls"))
            table[key] = v
        end
    end
    return table
end
