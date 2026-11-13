using Cascade, UnROOT, JSON3, SHA
using Cascade.IO
const I=Cascade.IO
function fingerprint(raw)
    records=String[]
    for name in sort!(collect(keys(raw)))
        value=raw[name]
        if value isa Jagged
            push!(records,name*":"*string(typeof(value))*":"*bytes2hex(sha256(reinterpret(UInt8,value.content)))*":"*bytes2hex(sha256(reinterpret(UInt8,value.offsets))))
        else
            push!(records,name*":"*string(typeof(value))*":"*bytes2hex(sha256(reinterpret(UInt8,value))))
        end
    end
    bytes2hex(sha256(join(records,"\n")))
end
function snapshot()
    out=Dict{String,Any}()
    for (file,keys) in (("status",["RssAnon","RssFile","VmHWM","VmRSS"]),("io",["read_bytes","write_bytes","rchar","wchar"]))
        vals=Dict{String,String}()
        try
            for line in eachline("/proc/self/"*file)
                pair=split(line,":";limit=2); length(pair)==2 && (vals[pair[1]]=strip(pair[2]))
            end
            for key in keys; out[key]=get(vals,key,nothing); end
        catch
            for key in keys; out[key]=nothing; end
        end
    end
    usage=zeros(Clong,18)
    rc=ccall(:getrusage,Cint,(Cint,Ptr{Clong}),0,usage)
    out["cpu_user_seconds"]=rc==0 ? usage[1]+usage[2]/1e6 : nothing
    out["cpu_sys_seconds"]=rc==0 ? usage[3]+usage[4]/1e6 : nothing
    out["minor_faults"]=rc==0 ? usage[9] : nothing
    out["major_faults"]=rc==0 ? usage[10] : nothing
    try
        stats=[parse.(Int,split(read(joinpath("/proc/self/task",tid,"schedstat"),String))) for tid in readdir("/proc/self/task")]
        out["task_sched_run_ns"]=sum(s[1] for s in stats);out["task_sched_wait_ns"]=sum(s[2] for s in stats)
    catch
        out["task_sched_run_ns"]=nothing;out["task_sched_wait_ns"]=nothing
    end
    return out
end
function main()
    src=NanoAODSource(ENV["CASCADE_DECODE_PILOT"])
    threads=parse(Int,ENV["JULIA_THREADS"])
    names=["event","genWeight","Muon_pt","Muon_eta","Muon_phi","Muon_mass","Muon_charge","Muon_tightId","Muon_pfRelIso04_all",
        "Electron_pt","Electron_eta","Electron_phi","Electron_mass","Electron_charge","Electron_cutBased",
        "Jet_pt","Jet_eta","Jet_phi","Jet_mass","Jet_jetId","Jet_btagDeepFlavB"]
    mask=[isodd(i) for i in 1:nevents(src)]
    try
        phase,reason=I.prepare_nanoaod_decode(src,names,mask,Dict{String,Any}("counter_reads"=>0);max_bytes=64*1024^2)
        isempty(reason)||error(reason)
        descriptors=phase.descriptors
        inventory=Dict("baskets"=>length(descriptors),"compressed_requested_bytes"=>sum(x.compressed for x in descriptors),
            "decoded_declared_bytes"=>sum(x.skip ? 0 : Int(x.key.fObjlen) for x in descriptors),
            "max_basket_reservation"=>maximum(x.charge for x in descriptors),"events"=>nevents(src),"branches"=>names)
        scan=function(d)
            with_decode_pipeline(src;threads=threads,diagnostics=d) do scope
                scope===nothing ? read_columns(src,names;needed=mask) : read_decoded_columns(scope,names;needed=mask)
            end
        end
        d=Dict{String,Any}(); warm=@timed scan(d); reference=fingerprint(warm.value)
        println(JSON3.write(Dict("kind"=>"warmup_excluded","threads"=>threads,"seconds"=>warm.time,"gc_seconds"=>warm.gctime,
            "allocated_bytes"=>warm.bytes,"fingerprint"=>reference,"inventory"=>inventory,"execution"=>d)))
        warm=nothing;GC.gc()
        for pass in 1:2
            before=snapshot();d=Dict{String,Any}();timed=@timed scan(d);after=snapshot()
            actual=fingerprint(timed.value);actual==reference||error("pilot science fingerprint changed")
            threads>1 && (!isempty(d["phase_fallbacks"])||d["phases"]!=1) && error("pilot did not use detached decoder")
            println(JSON3.write(Dict("kind"=>"measured","threads"=>threads,"pass"=>pass,"seconds"=>timed.time,"gc_seconds"=>timed.gctime,
                "compile_seconds"=>hasproperty(timed,:compile_time) ? timed.compile_time : nothing,
                "allocated_bytes"=>timed.bytes,"fingerprint"=>actual,"inventory"=>inventory,"before"=>before,"after"=>after,"execution"=>d)))
            flush(stdout);timed=nothing;GC.gc()
        end
    finally
        close_source(src)
    end
end
main()
