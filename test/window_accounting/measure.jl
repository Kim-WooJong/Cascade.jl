function measure()
 sel=RWH.object_selection(zeros(Int,3));pool=RWH.WindowBufferReuse(sel,4096,[8192,8192]);p=pool.progress
 off=collect(0:4096);counts=fill(Int32(1),4096)
 raw=Dict{String,Any}("w"=>ones(4096),"nJ"=>counts,"J_pt"=>RWH.Jagged(ones(4096),off),"J_eta"=>RWH.Jagged(ones(4096),off))
 wc=(counts=Dict("nJ"=>counts),offsets=Dict("nJ"=>off));p.offsets["J"]=off
 w=RWH.WindowAccounting(128)
 old=0;new=0
 for on in (false,true)
  pool.accounting=on ? w : nothing
  for _ in 1:20;RWH.reusable_window_bytes(raw,p,wc,p.needed;buffer_reuse=pool);end
  value=RWH.reusable_window_bytes(raw,p,wc,p.needed;buffer_reuse=pool)
  t=@timed for _ in 1:1000;RWH.reusable_window_bytes(raw,p,wc,p.needed;buffer_reuse=pool);end
  on ? (new=value) : (old=value)
  println("ACCOUNTING on=",on," charge=",value," bytes_per_call=",t.bytes/1000," allocs_per_call=",Base.gc_alloc_count(t.gcstats)/1000," seconds_1000=",t.time)
  on && @test t.bytes/1000 < 20160/4
 end
 @test new>=old
 # actual production finish check: owned check and independent scratch/native check.
 fb=RWH.FileBuilder();RWH.add_branch!(fb,"x",[1.0],[0,1];E=Float64)
 reader=RWH.build_reader(fb,[1:1];pre=["x"],post=String[],counters=Dict{String,String}())
 d=RWH.state_for(reader)
 live=new+length(d.scratch.raw)+RWE._nanoaod_decoder_limit()
 @test_throws ErrorException RWH._finish_reusable_window_read!(
  RWE.StreamWindowReader(reader.source,reader.branches,reader.pre,reader.post,reader.counters,reader.windows,reader.charges,
    (stream_window_bytes=new-1,stream_retained_bytes=10^9),reader.diagnostics,reader.seen),d,raw,p,wc,p.needed;buffer_reuse=pool)
 @test_throws ErrorException RWE.check_reusable_window_memory!(d,(stream_window_bytes=live-1,),new)
 @test RWE.check_reusable_window_memory!(d,(stream_window_bytes=live,),new)===nothing
 println("CAP owned_old=",old," owned_new=",new," live=",live," native=",RWE._nanoaod_decoder_limit()," checks=",w.checks)
end
@testset "warm allocation and cap" begin
 measure()
end
