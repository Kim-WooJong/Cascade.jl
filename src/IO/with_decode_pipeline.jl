"""Default one performs no dependency inspection, metadata preparation or spawning."""
function with_decode_pipeline(run, src::AbstractEventSource; threads = 1, queue_jobs = 32,
                              queue_bytes = 64*1024^2, diagnostics = Dict{String,Any}())
    (threads == "auto" || (threads isa Integer && !(threads isa Bool) && 1 <= threads <= typemax(Int))) || throw(ArgumentError("invalid decode_threads"))
    for value in (queue_jobs,queue_bytes)
        value isa Integer && !(value isa Bool) && 1 <= value <= typemax(Int) || throw(ArgumentError("invalid decode queue budget"))
    end
    requested = threads == "auto" ? Threads.nthreads() : Int(threads)
    actors = min(requested,Threads.nthreads(),Int(queue_jobs))
    merge!(diagnostics,Dict{String,Any}("requested_decode_threads"=>threads,"effective_actors"=>1,
        "decoder_workers"=>0,"max_active_decoders"=>0,"queue_jobs_highwater"=>0,"queue_bytes_highwater"=>0,
        "extra_opens"=>0,"extra_closes"=>0,"counter_reads"=>0,"basket_requests"=>0,"skipped_baskets"=>0,
        "compressed_requested_bytes"=>0,"decoded_declared_bytes"=>0,"max_basket_reservation"=>0,
        "phases"=>0,"phase_jobs_max"=>0,"phase_fallbacks"=>String[],"prepare_seconds"=>0.0,
        "assembly_seconds"=>0.0,"decode_task_seconds"=>0.0,"max_job_seconds"=>0.0,
        "decode_allocated_bytes"=>0,"max_job_allocated_bytes"=>0,"workers_joined"=>true))
    # Do not inspect version-dependent ROOT fields before the source contract.
    reason = requested == 1 ? "serial_requested" : actors < 2 ? "process_or_queue_budget" :
        !builtin_source_readers() ? "replaced_readers" : !(src isa NanoAODSource) ? "unsupported_source" :
        !isfile(src.path) ? "nonlocal_source" : ""
    diagnostics["fallback"] = reason
    isempty(reason) || return run(nothing)
    contract = decode_dependency_contract()
    diagnostics["dependency_contract"] = contract.record
    diagnostics["fallback"] = contract.reason
    isempty(contract.reason) || return run(nothing)
    reason = column_read_eligibility(src)
    diagnostics["fallback"] = reason
    isempty(reason) || return run(nothing)
    identity = decode_source_identity(src)
    if identity === nothing
        diagnostics["fallback"] = "unbound_mmap_identity"
        return run(nothing)
    end
    scope = DecodePipeline(src,actors,Int(queue_jobs),Int(queue_bytes),identity,diagnostics)
    result = run(scope) # Every phase joins before returning or throwing; source stays borrowed.
    decode_source_identity(src; expected = identity)
    return result
end
