# Comparison of Cascade.Corrections against correctionlib oracle output
# written by tools/oracle/correctionlib_oracle.py.
using Cascade
using Cascade.Corrections

decode_arg(a::AbstractString, t::AbstractString) = t == "string" ? String(a) : parse(Float64, a)
decode_arg(a::Integer, t::AbstractString) = Int64(a)
decode_arg(a::AbstractString, ::Nothing) = parse(Float64, a)   # extra argument (wrong-count case)
decode_arg(a::Integer, ::Nothing) = Int64(a)

function decode_args(args, types)
    return Tuple(decode_arg(a, i <= length(types) ? types[i] : nothing) for (i, a) in enumerate(args))
end

function same_value(j::Float64, p::Float64, rtol::Float64)
    (isnan(j) && isnan(p)) && return true, 0.0
    j == p && return true, 0.0
    (isinf(j) || isinf(p)) && return false, Inf
    rel = abs(j - p) / max(abs(p), floatmin(Float64))
    return rel <= rtol, rel
end

"""
    compare_oracle(oraclefile; csetpath=nothing, rtol=1e-12, maxreport=5, io=stdout)

Evaluate every recorded point with Cascade.Corrections and compare with the
correctionlib result: values must be identical or within relative `rtol`, and
an error must be raised exactly where correctionlib raised one. Vectorized
evaluation of the successful points is checked to be identical to the scalar
results. Returns a vector of per-correction NamedTuples.
"""
function compare_oracle(oraclefile::AbstractString; csetpath = nothing, rtol = 1e-12, maxreport = 5, io = stdout)
    o = Cascade.Corrections.read_json(read(oraclefile))
    cset = load_correctionset(csetpath === nothing ? o["source"] : csetpath)
    rows = NamedTuple[]
    for entry in o["corrections"]
        name = entry["name"]
        c = entry["compound"] ? compound_corrections(cset)[name] : cset[name]
        types = entry["input_types"]
        n = exact = close = errors_agree = mismatches = 0
        maxrel = 0.0
        reported = 0
        okargs = Any[]
        okvals = Float64[]
        for (args, res, err) in zip(entry["args"], entry["results"], entry["errors"])
            n += 1
            jargs = decode_args(args, types)
            jres = try
                evaluate(c, jargs...)
            catch e
                e
            end
            pyerr = err !== nothing
            jerr = jres isa Exception
            good = false
            if pyerr && jerr
                good = jres isa CorrectionError
                good && (errors_agree += 1)
            elseif !pyerr && !jerr
                p = parse(Float64, res)
                ok, rel = same_value(jres, p, rtol)
                if ok
                    rel == 0.0 ? (exact += 1) : (close += 1)
                    maxrel = max(maxrel, rel)
                    good = true
                    if length(jargs) == length(types)
                        push!(okargs, jargs)
                        push!(okvals, jres)
                    end
                else
                    maxrel = max(maxrel, rel)
                end
            end
            if !good
                mismatches += 1
                if reported < maxreport
                    reported += 1
                    println(io, "  MISMATCH ", name, " args=", jargs, " julia=", jerr ? sprint(showerror, jres) : jres,
                            " python=", pyerr ? err : parse(Float64, res))
                end
            end
        end
        vector_ok = check_vectorized(c, okargs, okvals, length(types))
        push!(rows, (name = name, compound = entry["compound"], points = n, exact = exact, close = close,
                     errors_agree = errors_agree, mismatches = mismatches, maxrel = maxrel, vector_ok = vector_ok))
    end
    return rows
end

"""Vectorized evaluation over the successful points must equal the scalar results."""
function check_vectorized(c, okargs, okvals, ninputs)
    (isempty(okargs) || ninputs == 0) && return true
    cols = ntuple(j -> collect_column([a[j] for a in okargs]), ninputs)
    out = evaluate(c, cols...)
    return all(i -> out[i] === okvals[i] || (isnan(out[i]) && isnan(okvals[i])), eachindex(okvals))
end

collect_column(v::Vector) = all(x -> x isa String, v) ? String.(v) : all(x -> x isa Int64, v) ? Int64.(v) : Float64.(v)

"""Print a per-file summary of compare_oracle rows; returns totals."""
function summarize_oracle(io, label, rows)
    t = (corrections = count(r -> !r.compound, rows), compound = count(r -> r.compound, rows),
         points = sum(r.points for r in rows; init = 0), exact = sum(r.exact for r in rows; init = 0),
         close = sum(r.close for r in rows; init = 0), errors_agree = sum(r.errors_agree for r in rows; init = 0),
         mismatches = sum(r.mismatches for r in rows; init = 0),
         maxrel = maximum((r.maxrel for r in rows); init = 0.0),
         vector_ok = all(r.vector_ok for r in rows))
    println(io, rpad(label, 34), " corrections=", t.corrections, " compound=", t.compound, " points=", t.points,
            " exact=", t.exact, " within_rtol=", t.close, " errors_agree=", t.errors_agree,
            " mismatches=", t.mismatches, " max_rel=", t.maxrel, " vectorized_identical=", t.vector_ok)
    return t
end
