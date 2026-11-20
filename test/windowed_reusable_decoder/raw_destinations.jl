# Standalone command: julia --threads=4 -e 'include("test/windowed_reusable_decoder/runtests.jl"); include("test/windowed_reusable_decoder/raw_destinations.jl")'
@testset "raw capacity lifetime, type changes and pre-allocation refusal" begin
    fb=RWH.FileBuilder();RWH.add_branch!(fb,"x",ones(Float32,4),[0,2,4];E=Float32)
    r=RWH.build_reader(fb,[1:2,3:4];pre=["x"],post=String[],counters=Dict{String,String}())
    d=RWH.state_for(r;reuse_destinations=true)
    a,n=RWE.reusable_destination!(d,"x",Float32,100,true)
    @test n==400 && d.destination_reserved==400
    b,n=RWE.reusable_destination!(d,"x",Float32,3,true)
    @test a===b && n==0 && d.destination_reserved==400
    b,n=RWE.reusable_destination!(d,"x",Float32,90,false)
    @test a===b && n==0 && d.destination_reserved==400
    b,n=RWE.reusable_destination!(d,"x",Float64,100,true)
    @test b isa Vector{Float64} && n==800 && d.destination_reserved==800
    b,n=RWE.reusable_destination!(d,"x",UInt8,200,true)
    @test n==200 && d.destination_reserved==200
    prior=d.destinations["x"]; d.destination_limit=250
    @test_throws ErrorException RWE.reusable_destination!(d,"x",Float64,1000,true)
    @test d.destinations["x"]===prior && d.destination_reserved==200
    @test_throws OverflowError RWE.reusable_destination!(d,"x",Float64,typemax(Int),true)
    RWE.release_reusable_stream!(d)
    @test isempty(d.destinations) && d.destination_reserved==0
end
@testset "production selected outputs never alias reusable raw" begin
    raw=Dict{String,Any}("w"=>[1e16,1.,-1e16,3.],"x"=>ones(4),"y"=>ones(4),"z"=>[11.,12.,13.,14.])
    fb=RWH.FileBuilder()
    for (name,v) in raw;RWH.add_branch!(fb,name,v,[0,2,4];E=Float64);end
    sel=RWH.scalar_selection();r=RWH.build_reader(fb,[1:2,3:4];pre=sel.columns_pre,post=sel.columns_post,counters=Dict{String,String}())
    d=RWH.state_for(r;reuse_destinations=true)
    got,a,diag,_=RWH.compare_reusable(sel,raw,r;n=4,decode=d)
    @test got["z"]==[11.,12.,13.,14.]
    @test diag["reusable_destination_allocated_bytes"]==64
    @test d.destination_reserved==64
end
