module TestReducedRoundtrip
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline, Cascade.Histograms
using ..ReducedFixtures
@testset "reduced shape union original normalization and standalone closure" begin
    mktempdir() do dir
        p=setup(dir); original=joinpath(dir,"original")
        run_pipeline(RunOptions(p;workdir=original,steps=STEPS_REDUCED))
        bundle=joinpath(dir,"bundle"); manifest=reduce_analysis(RunOptions(p);output_dir=bundle)
        @test length(manifest["files"])==1
        file=joinpath(bundle,"signal","00000001.root")
        src=open_source("reduced_rntuple",file)
        @test nevents(src)==3
        @test gen_weight_sum(src)==20.
        @test normalization_metadata(src)["provenance"]=="cols.meta.gen_weight_sum"
        cols=read_columns(src,["cascade_source_entry","event","nJet","Jet_pt"])
        @test cols["cascade_source_entry"]==[1,2,3]
        @test cols["event"]==UInt64[2^53+1,2^53+2,typemax(UInt64)]
        @test cols["Jet_pt"].content==Float32[29,31,40]
        @test cols["Jet_pt"].offsets==[0,1,2,3]
        @test cols["nJet"]==UInt32[1,1,1]
        extra=read_columns(src,["LHEPdfWeight","LHEScaleWeight"])
        @test extra["LHEPdfWeight"].content==repeat(Float64[1.,1.01,.99],3)
        @test extra["LHEScaleWeight"].content==repeat(Float32[1.,.9,1.1],3)
        @test src.meta["original_cutflows"]["nominal"]["n"]==[4,2]
        close_source(src)
        rp=joinpath(bundle,"analysis.toml"); reduced=joinpath(dir,"reduced")
        # Remove only synthetic originals, proving no original-backlink dependency.
        rm(joinpath(dir,"input");recursive=true)
        run_pipeline(RunOptions(rp;workdir=reduced,steps=STEPS_REDUCED))
        for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
            @test compare_stores(joinpath(original,rel),joinpath(reduced,rel))
        end
        info=json(joinpath(reduced,"merge/samples.json")).samples.signal
        @test info.gen_weight_sum==20.
        @test info.norm==10.
        @test info.regions.signal.cutflow_yield==20.
        @test info.cutflow.n==[3,2]
        @test info.original_sources[1].original_cutflows.nominal.n==[4,2]
        store=read_store(joinpath(reduced,"merge/histograms.json"))
        for (label,y,var) in (("nominal",20.,1000.),("ScaleUp",40.,1400.),("ScaleDown",30.,900.))
            h=store["signal","signal",label,"pt"]
            @test sum(h.sumw)==y
            @test sum(h.sumw2)==var
        end
        table=Cascade.Selection.read_event_table(first(filter(x->occursin(r"^[a-f0-9]+\.cols$",basename(x)),readdir(joinpath(reduced,"select/signal");join=true))))
        @test table["entry"]==[2,3]
        @test table["source_entry"]==[2,3]
        work=joinpath(dir,"batch"); batch_plan(RunOptions(rp;workdir=work))
        @test batch_run(work;workers=1)["complete"]
        result=batch_merge(work)
        for rel in ("merge/histograms_raw.json","merge/histograms.json","systematics/templates.json")
            @test compare_stores(joinpath(reduced,rel),joinpath(result,rel))
        end
        @test builtin_source_readers()
        @test Cascade.Pipeline.main(["reduce"])==2
    end
end
@testset "zero-retained original population is normalized once" begin
    mktempdir() do dir
        p=setup(dir;zero_file=true,theory=false)
        bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
        z=open_source("reduced_rntuple",joinpath(bundle,"signal/00000002.root"))
        @test nevents(z)==0; @test gen_weight_sum(z)==5.; close_source(z)
        out=joinpath(dir,"run")
        run_pipeline(RunOptions(joinpath(bundle,"analysis.toml");workdir=out,steps=STEPS_REDUCED))
        info=json(joinpath(out,"merge/samples.json")).samples.signal
        @test info.gen_weight_sum==25.
        @test info.norm==8.
        @test info.nfiles==2
    end
end
end
