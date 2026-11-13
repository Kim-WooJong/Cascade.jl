struct SyntheticBranchElement <: UnROOT.TBranchElement end
@testset "checked XZ only; zlib remains on the old serial decoder" begin
    payload=hex2bytes("789cab000000790079")
    frame=vcat(UInt8[0x5a,0x4c,0x08,length(payload),0,0,1,0,0],payload)
    key=UnROOT.TBasketKey(fNbytes=length(frame)+32,fVersion=1,fObjlen=1,fDatime=0,fKeylen=32,
        fCycle=1,fSeekKey=0,fSeekPdir=0,fClassName="TBasket",fName="x",fTitle="",fBufferSize=0,fNevBufSize=0,fNevBuf=1,fLast=33)
    @test I.validate_decode_blocks(frame,1)===nothing # pre-phase unsupported-codec signal
    @test UnROOT.decompress_datastreambytes(frame,key)==UInt8[0x78] # valid legacy path only
    badadler=copy(frame);badadler[end] ⊻= 0x01
    incomplete=copy(frame);incomplete[12]=0xaa # BFINAL ab->aa; checksum may still match output
    for bytes in (frame,badadler,incomplete)
        @test I.validate_decode_blocks(bytes,1)===nothing
        job=(key=key,bytes=bytes,blocks=(),T=UInt8,J=UnROOT.Nojagg,entries=1)
        @test_throws ErrorException I.decode_prepared_basket(job) # no native ZL call
    end
    doubled=vcat(frame,frame)
    @test I.validate_decode_blocks(doubled,2)===nothing
end
@testset "unreviewed branch elements and Offsetjagg excluded before dispatch" begin
    element=SyntheticBranchElement()
    @test !I.decode_interpretation_supported(element,Vector{Float32},UnROOT.Offsetjagg)
    @test !I.decode_interpretation_supported(element,Vector{Float32},UnROOT.Nooffsetjagg)
    @test !I.decode_interpretation_supported(element,Float32,UnROOT.Nojagg)
    @test !I.decode_interpretation_supported(nothing,Vector{Float32},UnROOT.Nooffsetjagg)
end
