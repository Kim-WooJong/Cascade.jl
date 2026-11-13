include("runtests.jl")
struct StepContext
    config::Any
    options::Any
end
struct ReducedRNTupleSource
    meta::Any
end
const Config=Main
const EventIO=Main
const SOURCE=Ref{Any}(nothing)
const LOG=String[]
streaming_selection_options(cfg)=(stream_metadata_bytes=100000,)
run_tasks(f,files;label="")=map(f,files)
open_source(format,path;options=Dict())=(push!(LOG,"open");SOURCE[])
source_signature(s)=(push!(LOG,"signature");Dict("format"=>"nanoaod","identity"=>17))
nevents(s)=(push!(LOG,"nevents");32853)
gen_weight_sum(s)=(push!(LOG,"runs");-0.0)
close_source(s)=push!(LOG,"close")
chunk_id(f)="logical-input-id"
is_data(s)=s.kind===:data
include("../../src/Pipeline/step_skim.jl")
function trial(;enabled=false,version=20,format="nanoaod",mode="configured",bad=false,variations=Any[])
    SOURCE[]=src(treebytes(Int64(32853);version,named_version=bad ? 99 : 1));empty!(LOG)
    ctx=StepContext((raw=Dict{String,Any}(),variations=variations),nothing)
    sample=(name="TT",kind=:mc,format=format,raw=Dict{String,Any}())
    result=skim_entries(ctx,sample,["logical-file"],Dict("mode"=>mode);lightweight_metadata=enabled)
    @test LOG[1:2]==["open","signature"]
    @test count(==("runs"),LOG)==1 && last(LOG)=="close"
    @test result[1]["nevents"]==32853 && reinterpret(UInt64,result[1]["gen_weight_sum"])==0x8000000000000000
    return result,copy(LOG)
end
@testset "actual skim helper, fake source only" begin
    off,l0=trial();on,l1=trial(enabled=true)
    @test on==off
    @test "nevents" in l0 && !("nevents" in l1)
    for kw in [(version=19,),(format="other",),(mode="certified",),(variations=Any[1],)]
        r,l=trial(;enabled=true,kw...)
        @test r==off && "nevents" in l
    end
    @test_throws ErrorException trial(enabled=true,bad=true)
    @test !("runs" in LOG) && last(LOG)=="close" # malformed prefix not swallowed, source still closed
end
println("PASS defaultOFF/ON skim record parity, signed -0 Runs unchanged/readonce, source identity before prefix, unsupported/certified/variation fallback, malformed fail+close")
