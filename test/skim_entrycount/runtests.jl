using Test, SHA
include("source_primitives.jl")
const UnROOT=FixtureUnROOT
struct NanoAODSource
    tree::String
    file::Any
end
include("../../src/IO/skim_nanoaod_entrycount.jl")
pack(x)=collect(reinterpret(UInt8,[hton(x)]))
strbytes(s)=vcat(UInt8[ncodeunits(s)],collect(codeunits(s)))
frame(v,body)=vcat(pack(UInt32(length(body)+2)|UInt32(0x40000000)),pack(UInt16(v)),body)
function treebytes(n::Int64;version=20,named_version=1,tail=UInt8[0xde,0xad,0xbe,0xef])
    tob=vcat(pack(UInt16(1)),pack(UInt32(0)),pack(UInt32(0)))
    named=frame(named_version,vcat(tob,strbytes("Events"),strbytes("synthetic")))
    line=frame(2,vcat(pack(Int16(1)),pack(Int16(1)),pack(Int16(1))))
    fill=frame(2,vcat(pack(Int16(0)),pack(Int16(0))))
    marker=frame(2,vcat(pack(Int16(1)),pack(Int16(1)),pack(Float32(1))))
    return frame(version,vcat(named,line,fill,marker,pack(n),tail))
end
@testset "exact existing streamer prefix" begin
    for n in Int64[0,1,32853,9007199254740993,typemax(Int64)]
        bytes=treebytes(n);io=IOBuffer(bytes)
        @test skim_ttree_prefix_entries(io;declared_bytes=length(bytes))===Int(n)
        @test position(io)==length(bytes)-4 # opaque branch tail untouched; not falsely validated
    end
    for v in (5,18,19,21,99)
        bytes=treebytes(Int64(17);version=v)
        @test skim_ttree_prefix_entries(IOBuffer(bytes);declared_bytes=length(bytes))===nothing
    end
    b=treebytes(Int64(2));no_count=vcat(pack(UInt16(20)),b[7:end])
    @test skim_ttree_prefix_entries(IOBuffer(no_count);declared_bytes=length(no_count))===nothing
    @test_throws ErrorException skim_ttree_prefix_entries(IOBuffer(treebytes(Int64(-1)));declared_bytes=length(treebytes(Int64(-1))))
    @test_throws ErrorException skim_ttree_prefix_entries(IOBuffer(treebytes(Int64(1);named_version=99));declared_bytes=length(treebytes(Int64(1);named_version=99)))
    for cut in (0,1,5,6,12,length(b)-5)
        @test_throws Exception skim_ttree_prefix_entries(IOBuffer(b[1:cut]);declared_bytes=cut)
    end
    bad=copy(b);bad[1:4]=pack(UInt32(0x40000006))
    @test_throws ErrorException skim_ttree_prefix_entries(IOBuffer(bad);declared_bytes=length(bad))
    @test_throws ErrorException skim_ttree_prefix_entries(IOBuffer(b);declared_bytes=length(b)-1)
end
if haskey(ENV,"CASCADE_UNROOT_SOURCE"); @test skim_entrycount_contract(;version=v"0.11.11",directory=ENV["CASCADE_UNROOT_SOURCE"]); else; @test_skip false; end
@test !skim_entrycount_contract(;version=v"0.11.10",directory=get(ENV,"CASCADE_UNROOT_SOURCE",""))
@test !skim_entrycount_contract(;version=v"0.11.11",directory=mktempdir())
# Pure in-memory outer I/O/key seam: does NOT prove native metadata codec/parser parity.
const READS=Ref(0)
@eval UnROOT function datastream(f,key)
    Main.READS[]+=1
    IOBuffer(f.mmap_ary[key.fKeylen+1:key.fNbytes])
end
skim_entrycount_contract()=true # test admission fixture only; real contract verified above
function src(bytes;name="Events",klass="TTree",keyversion=4,objlen=length(bytes),seek=0,nbytes=length(bytes)+64,keylen=64)
    key=(fName=name,fClassName=klass,fVersion=keyversion,fObjlen=objlen,fSeekKey=seek,fNbytes=nbytes,fKeylen=keylen)
    f=(fobj=UnROOT.MmapStream(vcat(zeros(UInt8,64),bytes)),lock=ReentrantLock(),directory=(keys=[key],),cache=Dict{Any,Any}())
    NanoAODSource(name,f)
end
@testset "outer bounds and no Events cache" begin
    s=src(treebytes(Int64(32853)));before=READS[]
    @test skim_nanoaod_entrycount(s;max_metadata_bytes=100000)==32853
    @test READS[]==before+1 && isempty(s.file.cache)
    @test skim_nanoaod_entrycount(src(treebytes(Int64(8));keyversion=3);max_metadata_bytes=100000)===nothing
    @test_throws ErrorException skim_nanoaod_entrycount(src(treebytes(Int64(8));keyversion=0);max_metadata_bytes=100000)
    @test skim_nanoaod_entrycount(src(treebytes(Int64(8));klass="Other");max_metadata_bytes=100000)===nothing
    @test skim_nanoaod_entrycount(src(treebytes(Int64(8));name="Events/nested");max_metadata_bytes=100000)===nothing
    @test_throws ErrorException skim_nanoaod_entrycount(src(treebytes(Int64(8));keylen=-1);max_metadata_bytes=100000)
    @test_throws ErrorException skim_nanoaod_entrycount(src(treebytes(Int64(8));seek=1);max_metadata_bytes=100000)
    @test_throws ErrorException skim_nanoaod_entrycount(s;max_metadata_bytes=16)
    @test_throws ErrorException skim_nanoaod_entrycount(src(treebytes(Int64(8));objlen=1);max_metadata_bytes=100000)
end
struct AnalysisConfig
    raw::Dict{String,Any}
end
include("../../src/Config/checkpoint_options.jl")
@test !lightweight_skim_metadata(Dict())
@test lightweight_skim_metadata(Dict("execution"=>Dict("lightweight_skim_metadata"=>true)))
for x in (0,1,"true",nothing)
    @test_throws ArgumentError lightweight_skim_metadata(Dict("execution"=>Dict("lightweight_skim_metadata"=>x)))
end
for p in filter(p->endswith(p,".jl"),[joinpath(d,n) for (d,_,ns) in walkdir(joinpath(@__DIR__,"../../src")) for n in ns])
    @test Meta.parseall(read(p,String)) isa Expr
end
println("PASS source-derived versioned prefix, exact Int64 including >2^53, unsupported-before-admission, malformed throws, caps, cache untouched, strictBool/defaultOFF")
println("NO native ROOT codec or real fEntries/Runs parity tested; real metadata-only gate required")
