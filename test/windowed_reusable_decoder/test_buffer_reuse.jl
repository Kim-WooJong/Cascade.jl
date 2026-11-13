using Test
include("runtests.jl")
@testset "reuse strict public config" begin
    @test !RWH.reuse_window_buffers(Dict())
    for x in (0, 1, "true", nothing)
        @test_throws ArgumentError RWH.reuse_window_buffers(Dict("execution"=>Dict("reuse_window_buffers"=>x)))
    end
    @test_throws ArgumentError RWH.reuse_window_buffers(Dict("execution"=>Dict("reuse_window_buffers"=>true)))
    cfg = Dict("execution"=>Dict("windowed_selection"=>true, "windowed_reusable_decoder"=>true, "reuse_window_buffers"=>true))
    @test RWH.reuse_window_buffers(cfg)
    cfg["execution"]["memoize_variables"] = true
    @test_throws ArgumentError RWH.reuse_window_buffers(cfg)
end
@testset "reset: zero/one/grow/shrink/active regrow, old offsets readonly" begin
    sel = RWH.object_selection(zeros(Int,3))
    pool = RWH.WindowBufferReuse(sel, 4096, [8192,8192]); p=pool.progress
    identities = (p.passed, p.failed, p.active, p.needed, p.current, p.objs.j.spans, p.objs.j.data, p.offsets)
    oldoffsets = [0,1,2]
    for n in (0,1,4096,7,0,4096,1)
        p.offsets["J"] = oldoffsets
        fill!(p.failed,true); fill!(p.needed,false); empty!(p.active)
        p.current[]=1; p.at=3; push!(p.objs.j.data,99)
        RWH.reset_window_buffers!(pool, sel, Dict{String,Any}(), n)
        @test p.active == collect(1:n) && all(iszero,p.passed)
        @test !any(p.failed) && all(p.needed) && p.current[]==0 && p.at==0
        @test isempty(p.offsets) && oldoffsets==[0,1,2]
        @test all(==(0:-1), p.objs.j.spans) && isempty(p.objs.j.data)
        @test all(a===b for (a,b) in zip(identities,(p.passed,p.failed,p.active,p.needed,p.current,p.objs.j.spans,p.objs.j.data,p.offsets)))
        if n>0
            p.current[]=1
            @test_throws ErrorException length(p.objs.j)
        end
    end
    raw=Dict{String,Any}(); RWH.reset_window_buffers!(pool,sel,raw,4096)
    resetbytes = @allocated RWH.reset_window_buffers!(pool,sel,raw,4096)
    createbytes = @allocated RWH.SelectionProgress(sel,raw,4096)
    println("REUSE_ALLOCATION reset_bytes=",resetbytes," creation_bytes=",createbytes," reserved_capacity_bytes=",pool.reserved_bytes)
    @test resetbytes < createbytes ÷ 20
    charged = RWH.reusable_window_bytes(raw,p;buffer_reuse=pool)
    RWH.reset_window_buffers!(pool,sel,raw,1)
    @test RWH.reusable_window_bytes(raw,p;buffer_reuse=pool) == charged
    p.raw["old"]=ones(2); p.offsets["J"]=oldoffsets
    RWH.detach_window_buffers!(pool)
    @test isempty(p.raw) && isempty(p.offsets) && oldoffsets==[0,1,2]
    @test_throws ErrorException RWH.reset_window_buffers!(pool,sel,raw,4097)
end
@testset "ON/OFF science native bits, objects, first-use, early regions, shared offsets and padded" begin
    for stages in (true,false), shared in (true,false), padded in (true,false), reuse in (true,false)
        calls=zeros(Int,3); sel=RWH.object_selection(calls;stages)
        w=[1e16,1.0,-1e16,3.0,-2.0]; x=[1.0,1.0,-1.0,1.0,1.0]
        jp=[[11.0],Float64[],[33.0],[44.0],[55.0]]; je=[[-1.0],Float64[],[1.0],[1.0],[1.0]]
        kp=[[101.0],[102.0],[103.0],[104.0],Float64[]]
        raw=Dict{String,Any}("w"=>w,"x"=>x,"J_pt"=>RWH.Jagged(jp),"J_eta"=>RWH.Jagged(je),"K_pt"=>RWH.Jagged(kp))
        fb=RWH.FileBuilder()
        for (name,col) in (("w",w),("x",x),("nJ",Int32.(length.(jp))),("nK",Int32.(length.(kp))))
            RWH.add_branch!(fb,name,col,[0,1,4,5];E=eltype(col))
        end
        for (name,col) in (("J_pt",jp),("J_eta",je),("K_pt",kp))
            RWH.add_branch!(fb,name,col,[0,1,4,5];E=Float64,jagged=true)
        end
        r=RWH.build_reader(fb,[1:1,2:4,5:5];pre=sel.columns_pre,post=sel.columns_post,counters=Dict("J_pt"=>"nJ","J_eta"=>"nJ","K_pt"=>"nK"),padded=padded ? Dict("J_pt"=>10) : Dict{String,Int}())
        d=RWH.state_for(r;share_window_offsets=shared)
        @test isempty(RWE.reusable_stream_admission(r,d))
        got,a,diag,d=RWH.compare_reusable(sel,raw,r;n=5,decode=d,reset=calls,reuse_buffers=reuse)
        if reuse
            @test r.diagnostics["window_buffer_creations"]==1 && r.diagnostics["window_buffer_resets"]==3
            @test r.diagnostics["window_buffer_capacity_highwater_bytes"]>0
        else
            @test !haskey(r.diagnostics,"window_buffer_creations")
        end
    end
end

@testset "reused scalar zero/one and all-false masks" begin
    for n in (0,1,7), stages in (true,false)
        sel=RWH.scalar_selection(;stages); fb=RWH.FileBuilder()
        raw=Dict{String,Any}("w"=>ones(n),"x"=>fill(-1.0,n),"y"=>ones(n),"z"=>ones(n))
        cuts=n==0 ? [0] : collect(0:n)
        for name in ("w","x","y","z"); RWH.add_branch!(fb,name,raw[name],cuts;E=Float64); end
        windows=n==0 ? [1:0] : [i:i for i in 1:n]
        r=RWH.build_reader(fb,windows;pre=sel.columns_pre,post=sel.columns_post,counters=Dict{String,String}())
        RWH.compare_reusable(sel,raw,r;n,reuse_buffers=true)
    end
end
