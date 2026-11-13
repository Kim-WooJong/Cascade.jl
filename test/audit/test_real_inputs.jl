module TestRealInputAudit
using Test, JSON3
using Cascade.Histograms

if get(ENV,"CASCADE_REAL_AUDIT","0")=="1"
    @testset "Actual metadata inventory and bounded pre-change equivalence" begin
        work=ENV["CASCADE_AUDIT_WORKDIR"]
        reference=ENV["CASCADE_AUDIT_REFERENCE"]
        full_reference=ENV["CASCADE_AUDIT_FULL_REFERENCE"]
        report=JSON3.read(read(joinpath(work,"out_inventory","audit","report.json"),String))
        @test report["status"]=="pass"
        @test report["finding_counts"]["error"]==0
        @test report["exposure"]["status"]=="unknown"
        @test report["event_id_duplicates"]=="not_assessed"
        nfiles=0;events=0
        for name in report["order"]
            sample=report["samples"][name]
            old=JSON3.read(read(joinpath(full_reference,"skim",name*".json"),String))
            @test sample["discovered_nfiles"]==sample["readable_nfiles"]==length(old["files"])
            @test sample["source_metadata_complete"]
            @test [f["path"] for f in sample["files"]]==[f["path"] for f in old["files"]]
            for (file,prior) in zip(sample["files"],old["files"])
                @test file["nevents"]==prior["nevents"]
                if sample["kind"]=="mc"
                    @test file["normalization"]["status"]=="available"
                    @test Float64(file["normalization"]["value"])===Float64(prior["gen_weight_sum"])
                else
                    @test file["normalization"]["status"]=="not_applicable"
                end
            end
            nfiles+=sample["discovered_nfiles"];events+=sample["nevents"]
        end
        @test nfiles==3307
        @test events==1_027_230_612
        old=JSON3.read(read(joinpath(reference,"out_bounded","merge","samples.json"),String))
        new=JSON3.read(read(joinpath(work,"out_bounded","merge","samples.json"),String))
        @test old["lumi_pb"]==new["lumi_pb"]
        @test old["order"]==new["order"]
        @test new["luminosity"]["exposure_status"]=="unknown"
        subsetfiles=0;subsetevents=0
        for name in old["order"]
            a=old["samples"][name];b=new["samples"][name]
            for key in ("nfiles","nevents","gen_weight_sum","norm","cutflow","regions")
                @test a[key]==b[key]
            end
            @test Float64(a["norm"])===Float64(b["norm"])
            @test haskey(b,"metadata")
            sa=JSON3.read(read(joinpath(reference,"out_bounded","skim",name*".json"),String))
            sb=JSON3.read(read(joinpath(work,"out_bounded","skim",name*".json"),String))
            @test [f["path"] for f in sa["files"]]==[f["path"] for f in sb["files"]]
            subsetfiles+=b["nfiles"];subsetevents+=b["nevents"]
        end
        bins=0
        for filename in ("histograms_raw.json","histograms.json")
            a=read_store(joinpath(reference,"out_bounded","merge",filename))
            b=read_store(joinpath(work,"out_bounded","merge",filename))
            @test Set(keys(a))==Set(keys(b))
            for key in keys(a)
                @test reinterpret(UInt64,a[key].edges)==reinterpret(UInt64,b[key].edges)
                @test reinterpret(UInt64,a[key].sumw)==reinterpret(UInt64,b[key].sumw)
                @test reinterpret(UInt64,a[key].sumw2)==reinterpret(UInt64,b[key].sumw2)
                bins+=length(a[key].sumw)
            end
        end
        @test subsetfiles==13
        write(joinpath(work,"real-verification.json"),JSON3.write(Dict("inventory_files"=>nfiles,"inventory_events"=>events,
            "bounded_files"=>subsetfiles,"bounded_events"=>subsetevents,"compared_bins"=>bins,"max_bit_difference"=>0)))
    end
end
end
