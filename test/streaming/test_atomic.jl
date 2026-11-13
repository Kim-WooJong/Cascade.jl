module TestStreamingAtomic
using Test, Cascade, TOML, SHA
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures
@testset "intermediate shard sidecar and final validation failures never publish" begin
mktempdir() do dir
    p=setup_stream(dir;window=1,shard=1,theory=false,target=512)
    source=joinpath(dir,"input/a.cols"); original=read(source)
    prior=joinpath(dir,"prior"); reduce_analysis(RunOptions(p);output_dir=prior)
    priorhash=bytes2hex(open(sha256,joinpath(prior,"manifest.json")))
    cols,meta,_=read_column_file(source)
    cols["Jet_pt"]=Jagged([Float32[29],Float32[31],fill(40f0,200),Float32[10]])
    cols["nJet"]=UInt32[1,1,200,1]; write_column_file(source,cols;meta)
    before=bytes2hex(open(sha256,source)); failed=joinpath(dir,"oversize")
    @test_throws ErrorException reduce_analysis(RunOptions(p);output_dir=failed)
    @test !ispath(failed); @test bytes2hex(open(sha256,source))==before
    write(source,original)
    corrupted=Ref(false)
    observer=function(window,buffer,metrics)
        corrupted[] && return
        for (base,_,names) in walkdir(dir), name in names
            occursin(".cascade-reduce-",base) && endswith(name,".cascade.json") || continue
            open(io->write(io," "),joinpath(base,name),"a"); corrupted[]=true; return
        end
    end
    failed=joinpath(dir,"sidecar")
    @test_throws ErrorException reduce_analysis(RunOptions(p);output_dir=failed,_observe_window=observer)
    @test corrupted[]; @test !ispath(failed)
    raw=TOML.parsefile(p); raw["fit"]=Dict("signal"=>["missing-group"],"channels"=>[Dict("region"=>"signal","variable"=>"pt")],"asimov"=>true)
    rewrite(p,raw); failed=joinpath(dir,"invalid-fit")
    @test_throws Exception reduce_analysis(RunOptions(p);output_dir=failed)
    @test !ispath(failed)
    @test bytes2hex(open(sha256,joinpath(prior,"manifest.json")))==priorhash
    @test read(source)==original
    delete!(raw,"fit"); rewrite(p,raw)
    claimed=Ref(false); target=joinpath(dir,"concurrent")
    observer_claim=function(window,buffer,metrics)
        claimed[] && return
        claimed[]=true
        project=normpath(joinpath(@__DIR__,"../..")); entry=joinpath(project,"bin/cascade.jl")
        cmd=Cmd(vcat(Base.julia_cmd().exec,["--startup-file=no","--project="*project,"--threads=1",entry,"reduce",p,"--output-dir",target]))
        @test run(ignorestatus(cmd)).exitcode==1
    end
    reduce_analysis(RunOptions(p);output_dir=target,_observe_window=observer_claim)
    @test claimed[]; @test only(groups(target))["retained_nevents"]==3
    changed=Ref(false)
    observer_drift=function(window,buffer,metrics)
        changed[] && return
        changed[]=true; sleep(.01); touch(source) # Only this disposable synthetic fixture.
    end
    failed=joinpath(dir,"source-drift")
    @test_throws ErrorException reduce_analysis(RunOptions(p);output_dir=failed,_observe_window=observer_drift)
    @test !ispath(failed); @test read(source)==original
    @test isempty(filter(n->startswith(n,".cascade-reduce-"),readdir(dir)))
end
end
end
