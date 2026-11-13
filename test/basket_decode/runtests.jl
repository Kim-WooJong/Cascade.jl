using Test, Cascade, UnROOT, JSON3, SHA
using Cascade.Config, Cascade.IO, Cascade.Selection
const I = Cascade.IO
@testset "decode config and audited dependency" begin
    @test decode_options(Dict()).threads == 1
    for width in (1,4,8,16,100000,"auto")
        raw=Dict("execution"=>Dict("decode_threads"=>width))
        @test decode_options(raw).threads == width
        @test validate_keys(raw) === raw
    end
    for key in ("decode_threads","decode_queue_jobs","decode_queue_bytes"), value in (true,false,0,-1,1.5,"bad")
        @test_throws ArgumentError validate_keys(Dict("execution"=>Dict(key=>value)))
        @test_throws ArgumentError validate_keys(Dict("profiles"=>Dict("inactive"=>Dict("execution"=>Dict(key=>value)))))
    end
    @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("decode_threads"=>4,"column_readers"=>2)))
    @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("decode_threads"=>"auto","column_readers"=>2)))
    @test I.decode_dependency_contract().reason == ""
    @test I.decode_dependency_contract(version=v"0.11.12").reason == "unsupported_unroot_version"
    mktempdir() do dir
        @test I.decode_dependency_contract(directory=dir).reason == "unroot_source_contract"
    end
end
@testset "bounded ordinal credits, failures and cancellation" begin
    for jobs in (1,2,4), budget in (10,20,40)
        got=Int[]; d=Dict{String,Any}()
        I.run_decode_queue(fill(10,12),identity,x->(sleep(0.001*(4-x%4));x),(k,v)->push!(got,v);
            actors=4,max_jobs=jobs,max_bytes=budget,diagnostics=d)
        @test got == collect(1:12)
        @test d["queue_jobs_highwater"] <= jobs
        @test d["queue_bytes_highwater"] <= budget
        @test d["workers_joined"]
    end
    if Threads.nthreads() >= 4
        entered=Threads.Atomic{Int}(0); released=Channel{Bool}(3); d=Dict{String,Any}()
        decoder=function(x)
            if Threads.atomic_add!(entered,1)==2
                for _ in 1:3; put!(released,true); end
            end
            take!(released); x
        end
        I.run_decode_queue(fill(1,3),identity,decoder,(k,v)->nothing;actors=4,max_jobs=3,max_bytes=3,diagnostics=d)
        @test d["max_active_decoders"] == 3
        @test entered[] == 3
    end
    for failing in (1,4), mode in (:decode,:prepare,:assemble)
        d=Dict{String,Any}(); finished=Threads.Atomic{Int}(0)
        prepare=k->(mode==:prepare && k==failing ? error("prepare") : k)
        decoder=k->try
            sleep(0.001*(5-k%4)); mode==:decode && k==failing && error("decode"); k
        finally
            Threads.atomic_add!(finished,1)
        end
        assemble=(k,v)->(mode==:assemble && k==failing && error("assemble"))
        e=try
            I.run_decode_queue(fill(1,8),prepare,decoder,assemble;actors=4,max_jobs=4,max_bytes=4,diagnostics=d); nothing
        catch e; e; end
        @test e isa I.DecodeJobError
        @test e.ordinal == failing
        @test !isempty(e.backtrace)
        @test d["workers_joined"]
    end
    d=Dict{String,Any}(); flag=Ref(false)
    @test_throws InterruptException I.run_decode_queue(fill(1,8),identity,identity,(k,v)->(flag[]=true);
        actors=4,max_jobs=2,max_bytes=2,diagnostics=d,cancelled=()->flag[])
    @test d["workers_joined"]
    @test_throws ErrorException I.run_decode_queue([11],identity,identity,(k,v)->nothing;actors=4,max_jobs=2,max_bytes=10)
    # Later failure completes first, but the lower admitted error wins.
    decoder=k->(sleep(k==1 ? 0.03 : 0.001); error("failure $k"))
    e=try I.run_decode_queue([1,1],identity,decoder,(k,v)->nothing;actors=3,max_jobs=2,max_bytes=2) catch e; e end
    @test e.ordinal==1
end
@testset "strict compressed framing and private uncompressed interpretation" begin
    for bad in (UInt8[],zeros(UInt8,8),zeros(UInt8,9))
        @test_throws ErrorException I.validate_decode_blocks(bad,10)
    end
    data=reinterpret(UInt8,hton.([UInt64(0xffffffffffffffff),UInt64(9007199254740993)])) |> collect
    key=UnROOT.TBasketKey(fNbytes=length(data)+32,fVersion=1,fObjlen=length(data),fDatime=0,fKeylen=32,
        fCycle=1,fSeekKey=0,fSeekPdir=0,fClassName="TBasket",fName="x",fTitle="",fBufferSize=0,fNevBufSize=0,fNevBuf=2,fLast=length(data)+32)
    job=(key=key,bytes=data,blocks=(),T=UInt64,J=UnROOT.Nojagg,entries=2)
    @test I.decode_prepared_basket(job)==[typemax(UInt64),UInt64(9007199254740993)]
    @test_throws ErrorException I.decode_prepared_basket(merge(job,(entries=3,)))
    @test_throws ErrorException I.decode_prepared_basket(merge(job,(bytes=view(data,:),)))
    d=Dict{String,Any}(); expected=copy(data)
    @test I.decode_prepared_basket(job)==reinterpret(UInt64,ntoh.(reinterpret(UInt64,expected)))
end
include("test_precompile.jl")
include("test_admission.jl")
include("test_supervision.jl")
include("test_codec_eligibility.jl")
if get(ENV,"CASCADE_DECODE_REAL","0")=="1"
    include("test_actual.jl")
end
