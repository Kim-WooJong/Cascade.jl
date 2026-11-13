module TestSampleAnnotations
using Test, Cascade.Config
@testset "Sample metadata and audit configuration contract" begin
    base=Dict{String,Any}("analysis"=>Dict("lumi_pb"=>100.),"samples"=>[Dict{String,Any}("name"=>"mc","kind"=>"mc","files"=>["x.cols"],"xsec_pb"=>1.)])
    raw=deepcopy(base)
    raw["samples"][1]["metadata"]=Dict{String,Any}("dataset"=>"/Primary/Processed/NANOAODSIM","era"=>"2022","campaign"=>"Summer22","xsec_source"=>"reference")
    raw["samples"][1]["audit"]=Dict{String,Any}("expected_nfiles"=>1,"expected_nevents"=>20,"expected_sumw"=>-5.,"sumw_atol"=>0.,"sumw_rtol"=>1e-8,"expected_files"=>["x.cols"],"inventory_source"=>"catalog")
    cfg=validate_analysis(parse_analysis(raw))
    @test cfg.samples[1].raw["metadata"]["era"]=="2022"
    @test cfg.samples[1].raw["audit"]["expected_sumw"]==-5.
    for (section,key,value) in (("metadata","era",2022),("metadata","era",""),("metadata","typo","x"),
        ("audit","expected_nfiles",true),("audit","expected_nevents",-1),("audit","expected_sumw",NaN),
        ("audit","sumw_rtol",-1.),("audit","sumw_atol",true),("audit","expected_files",["*.root"]),
        ("audit","expected_files",[2]),("audit","expected_filez",[]),("audit","inventory_source",""))
        bad=deepcopy(raw);bad["samples"][1][section][key]=value
        @test_throws ArgumentError validate_analysis(parse_analysis(bad))
    end
    for section in ("metadata","audit")
        bad=deepcopy(raw);bad["samples"][1][section]="invalid"
        @test_throws ArgumentError validate_analysis(parse_analysis(bad))
    end
end
end
