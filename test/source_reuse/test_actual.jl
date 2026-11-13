module TestActualSourceReuse
using Test, Cascade, TOML, JSON3
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Systematics, Cascade.Pipeline
const P = Cascade.Pipeline
if get(ENV,"CASCADE_SOURCE_REUSE_REAL","0") == "1"
@testset "bounded existing actual correction tables" begin
    project = normpath(joinpath(@__DIR__,"../.."))
    cfg = load_analysis(joinpath(project,"analyses/ttbar_emu/analysis.toml"); profile=get(ENV,"CASCADE_SOURCE_REUSE_PROFILE","theory_example"))
    # Reuse only persisted selection tables from an explicitly selected proof.
    # No old artifact is modified and no selection/full-data pipeline is launched.
    work = ENV["CASCADE_SOURCE_REUSE_REFERENCE"]
    timings = Dict{String,Any}()
    for name in ("TTto2L2Nu", "MuonEG")
        sample = sample_by_name(cfg,name)
        skim = P.read_skim(work,name)
        e = first(skim["files"]); path=String(e["path"]); chunk=String(e["chunk"])
        sel=P.chunk_path(work,:select,name,chunk,".cols")
        meta=P.read_meta(sel)
        labels=String.(get(meta,"shape",String[]))
        tables=[read_event_table(P.shape_chunk_path(work,:select,name,chunk,l,".cols")) for l in labels]
        push!(labels,"nominal"); push!(tables,read_event_table(sel))
        function compute(shared)
            owner=shared ? P.correction_chunk_source(apply_corrections,sample,path) : nothing
            try
                out=Any[]
                for (label,t) in zip(labels,tables)
                    w=apply_corrections(CorrectionContext(cfg,sample,path,t,label,owner))
                    label=="nominal" && (w=theory_member_weights(cfg,sample,path,t,w;source=owner))
                    push!(out,w)
                end
                out
            finally
                owner===nothing || close_source(owner)
            end
        end
        old=compute(false); new=compute(true)
        @test isequal(old,new)
        @test all(Set(keys(old[i]))==Set(keys(new[i])) && all(reinterpret(UInt64,old[i][k])==reinterpret(UInt64,new[i][k]) for k in keys(old[i])) for i in eachindex(old))
        oldtime=@elapsed compute(false)
        newtime=@elapsed compute(true)
        timings[name]=Dict("tables"=>length(tables), "nominal_rows"=>nrows(last(tables)), "old_seconds"=>oldtime,"shared_seconds"=>newtime,
            "source_path"=>path,"scope"=>"warm bounded correction wall time; no RDF or full pipeline claim")
    end
    println(JSON3.write(timings))
end
end
end
