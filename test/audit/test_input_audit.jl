module TestInputAudit
using Test, TOML, JSON3
using Cascade.Config, Cascade.IO, Cascade.Audit, Cascade.Pipeline
import Cascade.IO: nevents,column_names,read_columns,gen_weight_sum,source_signature,close_source,normalization_metadata

# An audited custom source throws if Events are touched and records handle closure.
struct MetadataOnlySource <: AbstractEventSource
    path::String
end
const closed=String[]
function nevents(s::MetadataOnlySource)
    if occursin("mutating",basename(s.path))
        open(io->write(io,"x"),s.path,"a")
    end
    return 3
end
struct UnsupportedMetadataSource <: AbstractEventSource
    path::String
end
nevents(::UnsupportedMetadataSource)=2
column_names(::MetadataOnlySource)=error("must not enumerate event columns")
read_columns(::MetadataOnlySource,args...;kwargs...)=error("must not read Events")
gen_weight_sum(::MetadataOnlySource)=4.
normalization_metadata(::MetadataOnlySource)=Dict{String,Any}("status"=>"available","value"=>4.,"provenance"=>"test metadata","entries"=>1,"message"=>"")
close_source(s::MetadataOnlySource)=push!(closed,s.path)
source_signature(s::MetadataOnlySource)=file_signature(s.path)

function setup(dir;weights=[2.,-1.],name="mc")
    p=joinpath(dir,name*".cols")
    write_column_file(p,Dict("genWeight"=>weights,"x"=>ones(length(weights))))
    raw=Dict{String,Any}("analysis"=>Dict("name"=>"audit","lumi_pb"=>100.,"workdir"=>joinpath(dir,"work")),
        "samples"=>[Dict{String,Any}("name"=>name,"kind"=>"mc","format"=>"cols","files"=>[p],"xsec_pb"=>2.)])
    return raw,p
end
cfg(raw,dir)=validate_analysis(parse_analysis(raw;dir))
codes(r)=Set(f["code"] for f in r["findings"])
perform_audit(raw,dir)=audit_inputs(cfg(raw,dir))

@testset "Fresh input audit contracts, identities and persistent failure reports" begin
    mktempdir() do dir
        raw,p=setup(dir)
        r=perform_audit(raw,dir)
        @test r["status"]=="pass"
        @test r["samples"]["mc"]["gen_weight_sum"]==1.
        @test r["samples"]["mc"]["inventory_completeness"]=="unknown"
        @test r["exposure"]["status"]=="unknown"
        @test r["event_id_duplicates"]=="not_assessed"
        @test r["samples"]["mc"]["declarations"]["branching_ratio"]=="defaulted"
        @test "metadata_unspecified" in codes(r)
        r["samples"]["mc"]["metadata"]=Dict("dataset"=>"A|B\nC")
        written=write_audit_report(r,joinpath(dir,"readable"))
        text=read(written[2],String)
        @test occursin("A\\|B C",text)
        @test occursin("## Declared sample provenance",text)
        audit=Dict{String,Any}("expected_nfiles"=>1,"expected_nevents"=>2,"expected_sumw"=>1.,"expected_files"=>[p],"inventory_source"=>"test catalog")
        raw["samples"][1]["audit"]=audit
        r=perform_audit(raw,dir)
        @test r["status"]=="pass"
        @test all(c["status"]=="pass" for c in r["samples"]["mc"]["checks"])
        @test r["samples"]["mc"]["inventory_completeness"]=="matched_declared_paths"
        # Count equality must not hide replaced membership.
        bad=deepcopy(raw);bad["samples"][1]["audit"]["expected_files"]=[joinpath(dir,"other.cols")]
        r=perform_audit(bad,dir)
        @test r["status"]=="fail" && "expected_files_mismatch" in codes(r)
        @test length(r["samples"]["mc"]["missing_expected_files"])==1
        bad=deepcopy(raw);bad["samples"][1]["audit"]["expected_files"]=["\${missing_path}/file.cols"]
        r=perform_audit(bad,dir)
        @test "invalid_expected_path" in codes(r)
        @test r["samples"]["mc"]["inventory_completeness"]=="invalid_contract"
        @test length(write_audit_report(r,joinpath(dir,"bad_contract")))==2
        bad=deepcopy(raw);push!(bad["samples"][1]["files"],joinpath(dir,"nothing*.cols"))
        r=perform_audit(bad,dir)
        @test "unmatched_pattern" in codes(r)
        @test r["samples"]["mc"]["readable_nfiles"]==1
        bad=deepcopy(raw);push!(bad["samples"][1]["files"],joinpath(dir,"absent.cols"))
        r=perform_audit(bad,dir)
        @test "missing_or_invalid_file" in codes(r)
        @test r["samples"]["mc"]["nevents"]===nothing
        @test r["samples"]["mc"]["partial_nevents"]==2
        @test only(c for c in r["samples"]["mc"]["checks"] if c["name"]=="expected_nevents")["status"]=="unknown"
        # Reports are generated before the CLI signals failure.
        path=joinpath(dir,"analysis.toml");open(io->TOML.print(io,bad),path,"w")
        @test main(["audit",path,"--workdir",joinpath(dir,"failed")])==1
        @test isfile(joinpath(dir,"failed","audit","report.md"))
        @test JSON3.read(read(joinpath(dir,"failed","audit","report.json"),String))["status"]=="fail"
        for arg in (["audit",path,"--max-files","1"],["audit",path,"--force"])
            @test_throws ArgumentError parse_cli(arg)
        end
        # Repeated identical pattern matches are de-duplicated by production.
        dup=deepcopy(raw);push!(dup["samples"][1]["files"],p)
        r=perform_audit(dup,dir)
        @test r["status"]=="pass" && "repeated_pattern_match" in codes(r)
        @test r["samples"]["mc"]["gen_weight_sum"]==1.
        alias=joinpath(dir,"alias.cols");symlink(p,alias)
        dup=deepcopy(raw);push!(dup["samples"][1]["files"],alias)
        @test "physical_file_alias" in codes(perform_audit(dup,dir))
        hard=joinpath(dir,"hard.cols");hardlink(p,hard)
        dup=deepcopy(raw);push!(dup["samples"][1]["files"],hard)
        @test "physical_file_alias" in codes(perform_audit(dup,dir))
        shared=deepcopy(raw);other=deepcopy(shared["samples"][1]);other["name"]="other";push!(shared["samples"],other)
        @test "cross_sample_file" in codes(audit_inputs(cfg(shared,dir);samples=["mc"]))
        @test_throws KeyError audit_inputs(cfg(shared,dir);samples=["unknown"])
        # Fresh audit sees changes without any artifact/cache reuse.
        oldhash=perform_audit(raw,dir)["provenance"]["input_signature_hash"]
        write_column_file(p,Dict("genWeight"=>[5.,-2.,1.],"x"=>ones(3)))
        @test perform_audit(raw,dir)["provenance"]["input_signature_hash"]!=oldhash
        @test "expected_nevents_mismatch" in codes(perform_audit(raw,dir))
    end
end

@testset "Signed normalization, incomplete totals and custom metadata-only source" begin
    mktempdir() do dir
        raw,p=setup(dir;weights=[-4.,1.])
        raw["samples"][1]["audit"]=Dict("expected_sumw"=>-3.,"sumw_rtol"=>0.,"sumw_atol"=>0.)
        @test perform_audit(raw,dir)["status"]=="pass"
        raw,p=setup(dir;weights=[1.,-1.])
        @test "zero_sample_sumw" in codes(perform_audit(raw,dir))
        zero=joinpath(dir,"zero.cols");cp(p,zero)
        raw,p=setup(dir;weights=[3.,-1.]);push!(raw["samples"][1]["files"],zero)
        r=perform_audit(raw,dir)
        @test r["status"]=="pass" && "zero_file_sumw" in codes(r)
        @test r["samples"]["mc"]["gen_weight_sum"]==2.
        corrupt=joinpath(dir,"corrupt.cols");write(corrupt,"bad");push!(raw["samples"][1]["files"],corrupt)
        r=perform_audit(raw,dir)
        @test r["status"]=="fail" && "source_read_failed" in codes(r)
        @test r["samples"]["mc"]["gen_weight_sum"]===nothing
        raw,p=setup(dir;weights=[1.,Inf])
        r=perform_audit(raw,dir)
        @test "normalization_invalid" in codes(r)
        @test r["samples"]["mc"]["gen_weight_sum"]===nothing
        @test length(write_audit_report(r,joinpath(dir,"nonfinite")))==2
        raw,p=setup(dir);raw["samples"][1]["format"]="audit_metadata_test"
        register_source_format!("audit_metadata_test",p->MetadataOnlySource(p))
        r=perform_audit(raw,dir)
        @test r["status"]=="pass"
        @test r["samples"]["mc"]["nevents"]==3
        @test p in closed
        @test r["samples"]["mc"]["gen_weight_sum"]==4.
        raw,p=setup(dir;name="mutating")
        raw["samples"][1]["format"]="audit_metadata_test"
        r=perform_audit(raw,dir)
        @test "input_changed_during_audit" in codes(r)
        @test r["samples"]["mutating"]["nevents"]===nothing
        raw,p=setup(dir)
        raw["samples"][1]["format"]="audit_unsupported_test"
        register_source_format!("audit_unsupported_test",p->UnsupportedMetadataSource(p))
        r=perform_audit(raw,dir)
        @test "normalization_unverified" in codes(r)
        @test r["samples"]["mc"]["gen_weight_sum"]===nothing
        raw,p=setup(dir);raw["samples"][1]["kind"]="data"
        r=perform_audit(raw,dir)
        @test r["samples"]["mc"]["normalization_status"]=="not_applicable"
        @test r["status"]=="pass"
    end
end
end
