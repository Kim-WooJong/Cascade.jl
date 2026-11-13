@testset "completed results retain both admission credits" begin
    prepared=Threads.Atomic{Int}(0);second_done=Threads.Atomic{Bool}(false)
    release=Channel{Bool}(1);d=Dict{String,Any}();order=Int[]
    observer=@async begin
        try
            @test timedwait(()->second_done[],5.0)==:ok
            @test prepared[]==2 # third payload cannot allocate while first waits
        finally
            put!(release,true)
        end
    end
    producer=k->(Threads.atomic_add!(prepared,1);k)
    decoder=k->begin
        k==1 && take!(release)
        k==2 && (second_done[]=true)
        k
    end
    I.run_decode_queue(fill(10,3),producer,decoder,(k,v)->push!(order,v);
        actors=3,max_jobs=2,max_bytes=20,diagnostics=d)
    wait(observer)
    @test order==[1,2,3]
    @test d["queue_jobs_highwater"]==2 && d["queue_bytes_highwater"]==20
    @test d["credits_reserved"]==d["credits_released"]==3
    @test d["bytes_reserved"]==d["bytes_released"]==30
    @test d["active_decoders_final"]==d["live_jobs_final"]==d["live_bytes_final"]==d["retained_payloads_final"]==0
    @test d["tasks_done"]
end
@testset "private jagged offsets and NaN bit payload" begin
    bits=UInt32[0x7fc01234,0x80000000]
    content=collect(reinterpret(UInt8,hton.(bits)))
    raw=vcat(content,zeros(UInt8,4),collect(reinterpret(UInt8,hton.(Int32[32,36]))),zeros(UInt8,4))
    key=UnROOT.TBasketKey(fNbytes=length(raw)+32,fVersion=1,fObjlen=length(raw),fDatime=0,fKeylen=32,
        fCycle=1,fSeekKey=0,fSeekPdir=0,fClassName="TBasket",fName="x",fTitle="",fBufferSize=0,fNevBufSize=0,fNevBuf=2,fLast=40)
    job=(key=key,bytes=copy(raw),blocks=(),T=Vector{Float32},J=UnROOT.Nooffsetjagg,entries=2)
    result=I.decode_prepared_basket(job)
    @test reinterpret(UInt32,result.data)==bits
    @test collect(result.elem_ptr)==[1,2,3]
    for offsets in (Int32[31,36],Int32[32,31],Int32[32,41],Int32[32,35])
        bad=copy(raw);bad[13:20]=collect(reinterpret(UInt8,hton.(offsets)))
        @test_throws ErrorException I.decode_prepared_basket(merge(job,(bytes=bad,)))
    end
end

@testset "XZ indexed decoded size before native allocation" begin
    stream=hex2bytes("fd377a585a000004e6d6b4460200210116000000742fe5a3010000780000000045aeef83f8ee160a00011901a52c81cc1fb6f37d010000000004595a")
    c=length(stream)
    frame=d->vcat(UInt8[0x58,0x5a,0, c&255,(c>>8)&255,(c>>16)&255,d,0,0],stream)
    good=frame(1)
    @test length(I.validate_decode_blocks(good,1))==1
    @test_throws ErrorException I.validate_decode_blocks(frame(2),2)
    @test_throws ErrorException I.validate_decode_blocks(frame(0),0)
    bad=copy(good);bad[end-7:end-4].=0xff
    @test_throws ErrorException I.validate_decode_blocks(bad,1)
    key=UnROOT.TBasketKey(fNbytes=length(good)+32,fVersion=1,fObjlen=1,fDatime=0,fKeylen=32,
        fCycle=1,fSeekKey=0,fSeekPdir=0,fClassName="TBasket",fName="x",fTitle="",fBufferSize=0,fNevBufSize=0,fNevBuf=1,fLast=33)
    job=(key=key,bytes=good,blocks=I.validate_decode_blocks(good,1),T=UInt8,J=UnROOT.Nojagg,entries=1)
    @test I.decode_prepared_basket(job)==UInt8[0x78]
    corrupt=copy(good);corrupt[20] ⊻= 0x01
    @test_throws Exception I.decode_prepared_basket(merge(job,(bytes=corrupt,)))
end
