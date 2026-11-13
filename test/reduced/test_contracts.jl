module TestReducedContracts
using Test, Cascade, TOML, JSON3, SHA
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..ReducedFixtures
@testset "reduced dependency size publication and stale contract guards" begin
    mktempdir() do dir
        p=setup(dir;theory=false); raw=TOML.parsefile(p)
        for settings in (Dict("drop"=>["Jet_pt"]),Dict("include"=>["missing"]),Dict("max_events"=>3),Dict("max_payload_bytes"=>4),Dict("max_input_bytes"=>4),Dict("max_buffer_bytes"=>4))
            raw["reduced_skim"]=merge(settings,Dict("mode"=>"legacy_eager")); rewrite(p,raw)
            dest=joinpath(dir,"bad-"*string(length(readdir(dir))))
            @test_throws Exception reduce_analysis(RunOptions(p);output_dir=dest)
            @test !ispath(dest)
        end
        raw["reduced_skim"]=Dict("mode"=>"legacy_eager"); rewrite(p,raw)
        bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
        before=read(joinpath(bundle,"manifest.json"))
        Cascade.Pipeline.batch_lock(joinpath(dir,"busy.reduce.lock")) do
            @test_throws Exception reduce_analysis(RunOptions(p);output_dir=joinpath(dir,"busy"))
        end
        hookraw=deepcopy(raw); hookraw["hooks"]=Dict("correct"=>"Main.unverified_hook")
        hookpath=rewrite(joinpath(dir,"hook.toml"),hookraw)
        @test_throws Exception reduce_analysis(RunOptions(hookpath);output_dir=joinpath(dir,"hook"))
        @test_throws Exception reduce_analysis(RunOptions(p);output_dir=bundle)
        @test read(joinpath(bundle,"manifest.json"))==before
        symlink(bundle,joinpath(dir,"link"))
        @test_throws Exception reduce_analysis(RunOptions(p);output_dir=joinpath(dir,"link","new"))
        rp=joinpath(bundle,"analysis.toml"); rr=TOML.parsefile(rp)
        rr["histograms"][1]["edges"]=[0.,50.,100.]; rewrite(rp,rr)
        @test Cascade.Pipeline.validate_reduced_inputs(load_analysis(rp))===nothing
        rr["cuts"][1]["expr"]="length(jets) >= 0"; rewrite(rp,rr)
        @test_throws Exception run_pipeline(RunOptions(rp;workdir=joinpath(dir,"stale"),steps=[:skim]))
        rr["cuts"][1]["expr"]=raw["cuts"][1]["expr"]; rewrite(rp,rr)
        # Duplicated derivations are rejected even when root paths differ.
        copied=joinpath(dir,"copy"); cp(bundle,copied)
        rr["samples"][1]["files"]=[joinpath(bundle,"signal/00000001.root"),joinpath(copied,"signal/00000001.root")]
        rewrite(rp,rr)
        @test_throws Exception run_pipeline(RunOptions(rp;workdir=joinpath(dir,"duplicate"),steps=[:skim]))
        @test Cascade.Audit.audit_inputs(load_analysis(rp))["status"]=="fail"
        file=joinpath(bundle,"signal/00000001.root"); side=file*".cascade.json"
        bytes=read(side); write(side,string(String(copy(bytes))," "))
        @test_throws Exception open_source("reduced_rntuple",file)
        write(side,bytes)
        bytes=read(file); open(file,"a") do io; write(io,UInt8(0)); end
        @test_throws Exception open_source("reduced_rntuple",file)
        write(file,bytes)
        s=open_source("reduced_rntuple",file); @test nevents(s)==3; close_source(s)
    end
end
@testset "missing negative zero original denominator and aggregate zero" begin
    for value in (nothing,-20.,0.)
        mktempdir() do dir
            p=setup(dir;theory=false); f=joinpath(dir,"input/a.cols")
            cols,meta,_=read_column_file(f)
            value===nothing ? delete!(meta,"gen_weight_sum") : (meta["gen_weight_sum"]=value)
            write_column_file(f,cols;meta)
            bundle=joinpath(dir,"bundle")
            if value===nothing
                @test_throws Exception reduce_analysis(RunOptions(p);output_dir=bundle)
                @test !ispath(bundle)
            else
                reduce_analysis(RunOptions(p);output_dir=bundle)
                s=open_source("reduced_rntuple",joinpath(bundle,"signal/00000001.root"))
                @test gen_weight_sum(s)==value
                @test normalization_metadata(s)["status"]=="available"; close_source(s)
                if value==0.
                    @test_throws Exception run_pipeline(RunOptions(joinpath(bundle,"analysis.toml");workdir=joinpath(dir,"run"),steps=STEPS_REDUCED))
                end
            end
        end
    end
end
end
