"""Opt-in stage owner: no file-worker fanout around the bounded decoder pool.

Keep completed per-file artifacts and attempt subsequent files like run_tasks.
All other stages and default selection retain the existing scheduler.
"""
function run_decode_file_tasks(f, items::AbstractVector; label::AbstractString = "")
    results = Vector{Any}(undef,length(items)); errors = Any[]; start = time()
    for (k,item) in enumerate(items)
        try
            results[k] = f(item)
        catch e
            push!(errors,(k,e,catch_backtrace()))
        end
        isempty(label) || println("  [",label,"] ",k,"/",length(items)," (",round(time()-start;digits=1)," s)")
    end
    for (k,e,bt) in errors[1:min(end,3)]
        println(stderr,"task ",k," failed: ",sprint(showerror,e,bt;context=:limit=>true))
    end
    isempty(errors) || error("$(length(errors)) of $(length(items)) $label tasks failed")
    return results
end
