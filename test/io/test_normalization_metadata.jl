module TestNormalizationMetadata
using Test
using Cascade.IO

@testset "Normalization metadata provenance and signed sums" begin
    mktempdir() do dir
        function inspect(name, cols; meta=Dict{String,Any}(), gen_weight="genWeight")
            path=joinpath(dir,name*".cols")
            write_column_file(path,cols;meta)
            source=ColumnFileSource(path;gen_weight)
            try
                return normalization_metadata(source),gen_weight_sum(source)
            finally
                close_source(source)
            end
        end
        for weights in ([4.,-1.],[-4.,1.],[1.,-1.])
            r,old=inspect(string(weights),Dict("genWeight"=>weights))
            @test r["status"]=="available"
            @test r["value"]===old
            @test r["entries"]==2
        end
        r,old=inspect("meta",Dict("genWeight"=>[1.,2.]);meta=Dict("gen_weight_sum"=>-15.))
        @test r["value"]==old == -15.
        @test r["provenance"]=="cols.meta.gen_weight_sum"
        r,_=inspect("alias",Dict("weight"=>[2.,3.]);gen_weight="weight")
        @test r["value"]==5.
        r,old=inspect("missing",Dict("x"=>[1.,2.]))
        @test r["status"]=="missing" && r["value"]===nothing && old==0.
        for (i,value) in enumerate((NaN,Inf,-Inf))
            p=joinpath(dir,"invalid$i.cols")
            write_column_file(p,Dict("genWeight"=>[1.,value]))
            @test normalization_metadata(ColumnFileSource(p))["status"]=="invalid"
        end
        p=joinpath(dir,"overflow.cols")
        write_column_file(p,Dict("genWeight"=>[floatmax(Float64),floatmax(Float64)]))
        @test normalization_metadata(ColumnFileSource(p))["status"]=="invalid"
        for (i,value) in enumerate((true,NaN,Inf,"bad"))
            p=joinpath(dir,"badmeta$i.cols")
            # JSON cannot encode nonfinite metadata; nonnumeric/bool cases are persisted,
            # floating invalid cases exercise the in-memory metadata interface directly.
            write_column_file(p,Dict("x"=>[1.]))
            src=ColumnFileSource(p);src.meta["gen_weight_sum"]=value
            @test normalization_metadata(src)["status"]=="invalid"
        end
    end
end

if haskey(ENV,"CASCADE_AUDIT_ROOT_FIXTURES")
    @testset "Actual ROOT header and Runs metadata" begin
        dir=ENV["CASCADE_AUDIT_ROOT_FIXTURES"]
        for (file,status,value) in (("valid","available",3.),("negative","available",-3.),
                                    ("zero","available",0.),("no_runs","missing",nothing),
                                    ("no_branch","missing",nothing),("nonfinite","invalid",nothing),
                                    ("vector","invalid",nothing),("boolean","invalid",nothing))
            src=NanoAODSource(joinpath(dir,file*".root"))
            try
                r=normalization_metadata(src)
                @test r["status"]==status
                @test r["value"]===value
                @test nevents(src)==1
                status=="available" && (@test r["value"]===gen_weight_sum(src))
            finally
                close_source(src)
            end
        end
        src=NanoAODSource(joinpath(dir,"aliases.root");tree="MyEvents",runs_tree="MyRuns",gen_sumw="sumw")
        try
            @test normalization_metadata(src)["value"]==3.
            @test nevents(src)==1
        finally
            close_source(src)
        end
    end
end
end
