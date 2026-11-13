@testset "ON/OFF science native bits, objects, first-use, early regions, shared offsets and padded" begin
    for stages in (true,false), shared in (true,false), padded in (true,false), accounting in (false,true)
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
        got,a,diag,d=RWH.compare_reusable(sel,raw,r;n=5,decode=d,reset=calls,reuse_buffers=true,reuse_accounting=accounting)
        if true
            @test r.diagnostics["window_buffer_creations"]==1 && r.diagnostics["window_buffer_resets"]==3
            @test r.diagnostics["window_buffer_capacity_highwater_bytes"]>0

        end
    end
end
