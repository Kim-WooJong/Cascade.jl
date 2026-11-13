"""Phase-local detached basket execution; no decoded data is cached between masks."""
function read_decoded_columns(scope::DecodePipeline, names; needed = nothing)
    src = scope.original; d = scope.diagnostics
    decode_source_identity(src; expected = scope.identity)
    start = time_ns()
    phase, reason = prepare_nanoaod_decode(src, unique(names), needed, d; max_bytes = scope.bytes)
    d["prepare_seconds"] += (time_ns()-start)/1e9
    if phase === nothing
        push!(d["phase_fallbacks"], reason); d["fallback"] = reason
        return read_columns(src,names;needed)
    end
    plans = phase.plans; descriptors = phase.descriptors
    states = map(plans) do p
        values = p.jagged ? (p.masked ? zeros(p.E,p.offsets[end]) : p.E[]) : Vector{p.E}(undef,p.n)
        offsets = p.jagged ? (p.masked ? copy(p.offsets) : zeros(Int,p.n+1)) : Int[]
        (values=values,offsets=offsets)
    end
    d["phases"] += 1; d["fallback"] = ""
    d["phase_jobs_max"] = max(d["phase_jobs_max"],length(descriptors))
    prepare = function(k)
        desc = descriptors[k]; p = plans[desc.branch]
        desc.skip && return nothing
        bytes = UnROOT.read_seek_nb(src.file.fobj, desc.pos, desc.compressed)
        d["compressed_requested_bytes"] += desc.compressed
        d["decoded_declared_bytes"] += Int(desc.key.fObjlen)
        d["basket_requests"] += 1
        d["max_basket_reservation"] = max(d["max_basket_reservation"],desc.charge)
        return (key = desc.key, bytes = bytes, blocks = desc.blocks, T = p.T, J = p.J, entries = desc.hi-desc.lo+1)
    end
    assemble = function(k,result)
        desc = descriptors[k]
        desc.skip && (d["skipped_baskets"] += 1)
        t = time_ns()
        assemble_decoded_basket!(plans[desc.branch],states[desc.branch],desc,result)
        d["assembly_seconds"] += (time_ns()-t)/1e9
    end
    run_decode_queue([x.charge for x in descriptors],prepare,
        job -> job === nothing ? nothing : decode_prepared_basket(job),assemble;
        actors = scope.actors, max_jobs = scope.jobs, max_bytes = scope.bytes, diagnostics = d)
    decode_source_identity(src; expected = scope.identity)
    out = Dict{String,Any}()
    for (p,s) in zip(plans,states)
        out[p.name] = p.jagged ? Jagged(s.values,s.offsets) : s.values
    end
    return out
end
