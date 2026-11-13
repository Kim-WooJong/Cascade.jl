module TestStreamLimits
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures
@testset "independent row-byte budgets empty schema and no failed publication" begin
mktempdir() do dir
    p=setup_stream(dir;theory=false,shard=9,target=1000,window=3)
    file=joinpath(dir,"input/a.cols"); columns,metadata,_=read_column_file(file)
    for name in ("PSWeight","LHEPdfWeight","LHEScaleWeight"); delete!(columns,name); end
    write_column_file(file,columns;meta=metadata)
    raw=TOML.parsefile(p)
    @test reduced_skim_options(load_analysis(p))["mode"]=="streaming"
    raw["reduced_skim"]["max_events"]=3; rewrite(p,raw)
    @test_throws ErrorException load_analysis(p)
    delete!(raw["reduced_skim"],"max_events")
    # Raw row = provenance8 + event8 + genWeight4 + run4 + LS4 + nJet4 + Jet4 + offset8 =44, plus initial offset8.
    for (target,expected) in ((51,nothing),(52,[1,1,1]),(95,[1,1,1]),(96,[2,1]),(97,[2,1]))
        raw["reduced_skim"]["streaming"]["target_shard_payload_bytes"]=target; rewrite(p,raw)
        out=joinpath(dir,"target"*string(target))
        if expected===nothing
            @test_throws ErrorException reduce_analysis(RunOptions(p);output_dir=out)
            @test !ispath(out)
        else
            reduce_analysis(RunOptions(p);output_dir=out)
            @test [r["nevents"] for r in first(groups(out))["shards"]]==expected
            @test all(r["payload_bytes"]<=target for r in first(groups(out))["shards"])
        end
    end
    raw["reduced_skim"]["streaming"]["target_shard_payload_bytes"]=1000
    raw["reduced_skim"]["streaming"]["max_window_bytes"]=1; rewrite(p,raw)
    @test_throws Exception reduce_analysis(RunOptions(p);output_dir=joinpath(dir,"no-window"))
    @test !ispath(joinpath(dir,"no-window"))
    raw["reduced_skim"]["streaming"]["max_window_bytes"]=128000000; rewrite(p,raw)
    file=joinpath(dir,"input/a.cols"); cols,meta,_=read_column_file(file)
    zero=Dict{String,Any}(k=>c isa Jagged ? Jagged(eltype(c.content)[],[0]) : c[1:0] for (k,c) in cols)
    write_column_file(file,zero;meta)
    empty=joinpath(dir,"empty"); reduce_analysis(RunOptions(p);output_dir=empty)
    g=only(groups(empty)); @test g["original_nevents"]==0; @test g["retained_nevents"]==0
    @test length(g["shards"])==1; @test g["shards"][1]["source_end"]==0
    @test g["normalization"]["value"]==20.
    @test_throws Exception reduce_analysis(RunOptions(p);output_dir=empty)
    @test g==read_reduced_group(g["descriptor_path"])
end
end
end
