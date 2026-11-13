using Test, JSON3, SHA
using .Cascade.Config, .Cascade.IO, .Cascade.Selection
const SP=Cascade.Pipeline
const SI=Cascade.IO
function streamopts(;kwargs...)
    merge(streaming_selection_options(Dict()),(stream_metadata_bytes=64,stream_queue_bytes=1000,
        stream_queue_windows=4,stream_active_files=2,stream_retained_bytes=10000),NamedTuple(kwargs))
end
@testset "stream config defaults, profiles and scientific keys" begin
    @test !streaming_selection_options(Dict()).enabled
    @test streaming_selection_options(Dict("execution"=>Dict("streaming_selection"=>true))).enabled
    for key in keys(streaming_selection_options(Dict()))
        key==:enabled && continue
        for value in (true,false,0,-1,1.5,"bad")
            @test_throws ArgumentError validate_keys(Dict("execution"=>Dict(String(key)=>value)))
            @test_throws ArgumentError validate_keys(Dict("profiles"=>Dict("inactive"=>Dict("execution"=>Dict(String(key)=>value)))))
        end
    end
    for value in (1,0,"true",nothing)
        @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("streaming_selection"=>value)))
    end
    for engine in (Dict("decode_threads"=>4),Dict("decode_threads"=>"auto"),Dict("column_readers"=>2))
        @test_throws ArgumentError validate_keys(Dict("execution"=>merge(Dict("streaming_selection"=>true),engine)))
        @test_throws ArgumentError validate_keys(Dict("execution"=>Dict("streaming_selection"=>true),"profiles"=>Dict("inactive"=>Dict("execution"=>engine))))
    end
    raw=Dict("samples"=>[Dict("name"=>"fixture","kind"=>"data","files"=>["unused.cols"],"format"=>"cols")])
    cfg=parse_analysis(raw);cfg2=parse_analysis(merge(raw,Dict("execution"=>Dict("streaming_selection"=>true))))
    @test section_hash(cfg,"objects","cuts","weights")==section_hash(cfg2,"objects","cuts","weights")
    @test canonical_hash(cfg.raw)!=canonical_hash(cfg2.raw)
    @test SP.stream_selection_fallback(cfg,cfg.samples[1],nothing)==(Threads.nthreads()==1 ? "one_thread" : "unsupported_format")
end
function fixturedata(item,n;charge=10)
    (reader=(item=item,),analysis=(item=item,),windows=[k:k for k in 1:n],charges=fill(charge,n),retained_charges=fill(1,n))
end
function goodclose(d)
    @test true
end
function assertsettled(d)
    @test d["workers_joined"]
    @test d["active_workers_final"]==0
    @test d["live_windows_final"]==d["live_bytes_final"]==d["retained_bytes_final"]==0
    @test d["credits_reserved"]==d["credits_released"]
    @test d["bytes_reserved"]==d["bytes_released"]
    @test d["created_workers"]<=Threads.nthreads()-1
end
if Threads.nthreads()>=2
@testset "dynamic window credits, order, failures, startup, cancellation" begin
    actors=min(4,Threads.nthreads())
    for n in (0,1,3,7),maxjobs in (1,2,4)
        got=Dict(k=>Int[] for k in 1:3);closed=Int[];published=Int[];d=Dict{String,Any}()
        read=(r,k)->(sleep(.0001*(1+k%2));(item=r.item,k=k))
        analyze=(a,p,k)->(push!(got[a.item],p.k);0)
        SP.run_window_pipeline(collect(1:3),i->fixturedata(i,n),read,analyze,
            (f,r,a)->push!(published,f.analysis.item),f->push!(closed,f.analysis.item);
            options=streamopts(stream_queue_windows=maxjobs),actors,diagnostics=d)
        @test all(x==collect(1:n) for x in values(got));@test sort(closed)==sort(published)==[1,2,3]
        @test d["queue_windows_highwater"]<=maxjobs
        @test d["queue_bytes_highwater"]<=1000
        assertsettled(d)
    end
    for mode in (:read,:analysis,:publish,:open,:before_start,:after_publish,:controller,:partialspawn,:interrupt,:cancel)
        d=Dict{String,Any}();closed=Int[];flag=Ref(false)
        opener=i->(mode==:open && error("open primary");fixturedata(i,3))
        read=(r,k)->(mode==:read && k==2 && error("read primary");mode==:interrupt && k==1 && throw(InterruptException());(item=r.item,k=k))
        analyze=(a,p,k)->(mode==:analysis && k==1 && error("analysis primary");0)
        publish=(f,r,a)->(mode==:publish && error("publication primary"))
        hook=(stage,k)->(mode==:before_start && stage==:before_start_wait && error("startup fatal");mode==:after_publish && stage==:after_publish && error("late fatal"))
        spawn=(stage,k,t)->(mode==:partialspawn && stage==:before_start && k==1 && error("partial spawn primary"))
        control=(stage,v)->begin
            mode==:controller && stage==:after_admit && error("controller primary")
            mode==:cancel && stage==:after_admit && (flag[]=true)
        end
        err=try
            SP.run_window_pipeline([1],opener,read,analyze,publish,f->push!(closed,f.analysis.item);
                options=streamopts(stream_queue_windows=1),actors,diagnostics=d,worker_hook=hook,
                spawn_hook=spawn,controller_hook=control,cancelled=()->flag[]);nothing
        catch e;e end
        @test err!==nothing
        @test length(closed)<=1
        mode in (:interrupt,:cancel) && @test err isa InterruptException
        assertsettled(d)
    end
    # Cleanup failures cannot mask the controller's primary error.
    d=Dict{String,Any}()
    err=try
        SP.run_window_pipeline([1],i->fixturedata(i,3),(r,k)->k,(a,p,k)->0,(f,r,a)->nothing,
            f->error("secondary close");options=streamopts(),actors,diagnostics=d,
            controller_hook=(s,v)->(s==:after_admit && error("primary controller")));nothing
    catch e;e end
    @test occursin("primary controller",sprint(showerror,err));assertsettled(d)
    # Failed later file retains already completed checkpoints, with no publication
    # for its unfinished windows. The close callback sees no jobs still active.
    published=Int[];d=Dict{String,Any}()
    @test_throws Exception SP.run_window_pipeline([1,2],i->fixturedata(i,3),
        (r,k)->(r.item==2 && k==2 && error("second file");k),(a,p,k)->0,
        (f,r,a)->push!(published,f.analysis.item),goodclose;
        options=streamopts(stream_active_files=1),actors,diagnostics=d)
    @test published==[1];assertsettled(d)
    @test_throws Exception SP.run_window_pipeline([1],i->fixturedata(i,3;charge=1001),
        (r,k)->k,(a,p,k)->0,(f,r,a)->nothing,goodclose;options=streamopts(),actors)
end
end
if Threads.nthreads()>=3
@testset "required SAME FILE read-next overlaps analysis-current" begin
    entered_read=Threads.Atomic{Bool}(false);entered_analysis=Threads.Atomic{Bool}(false);overlap=Ref(false);d=Dict{String,Any}()
    read=(r,k)->begin
        if k==2
            entered_read[]=true
            timedwait(()->entered_analysis[],5)==:ok || error("same-file analysis never overlapped")
        end
        (raw=Dict("owned"=>[k]),range=k:k,needed=nothing)
    end
    analyze=(a,p,k)->begin
        if k==1
            entered_analysis[]=true
            timedwait(()->entered_read[],5)==:ok || error("same-file read-next never overlapped")
            overlap[]=true
        end
        @test p.raw["owned"]==[k]
        @test !any(v->v isa AbstractEventSource,values(p))
        0
    end
    SP.run_window_pipeline([1],i->fixturedata(i,3),read,analyze,(f,r,a)->nothing,goodclose;
        options=streamopts(),actors=min(4,Threads.nthreads()),diagnostics=d)
    @test overlap[];assertsettled(d)
end
end
@testset "persistent cutflow catastrophic cancellation and original metadata" begin
    cfg=parse_analysis(Dict("samples"=>[Dict("name"=>"x","kind"=>"mc","xsec_pb"=>1.,"files"=>["unused"])],
        "analysis"=>Dict("lumi_pb"=>1.),"weights"=>Dict("mc"=>["genWeight"]),
        "cuts"=>[Dict("name"=>"positive","expr"=>"x > 0")],
        "regions"=>[Dict("name"=>"inclusive","after"=>"positive","expr"=>"x > 0")]))
    sel=compile_selection(cfg,:mc)
    raw=Dict{String,Any}("genWeight"=>[1e16,1.,-1e16,3.,-2.],"x"=>ones(5))
    ref,cf=select_events(sel,raw,5;sample="x")
    a=SP.StreamSelectionAnalysis(sel,"x")
    for (k,range) in enumerate((1:1,2:3,4:5))
        sub=Dict{String,Any}(key=>copy(v[range]) for (key,v) in raw)
        SP.analyze_stream_selection_window(a,(raw=sub,range=range,needed=nothing),k)
    end
    got=SP.finish_stream_selection!(a,5)
    @test isequal(got.meta,ref.meta)
    @test cutflow_dict(a.cutflow)==cutflow_dict(cf)
    @test all(reinterpret(UInt8,got[key])==reinterpret(UInt8,ref[key]) for key in ref.order)
    @test a.cutflow.sumw[1]==1.0
    @test !any(v->v isa AbstractEventSource,(getfield(a,k) for k in fieldnames(typeof(a))))
end

if Threads.nthreads()>=3
@testset "whole-worker lifecycle, join-before-close and low error frontier" begin
 actors=min(4,Threads.nthreads())
 for stage in (:before_input,:before_active,:after_active,:before_decode,:after_decode,:before_publish,:after_publish)
  d=Dict{String,Any}();active=Threads.Atomic{Int}(0);closed=Ref(false)
  read=(r,k)->try
   Threads.atomic_add!(active,1);sleep(.001);k
  finally Threads.atomic_add!(active,-1) end
  hook=(s,k)->(s==stage && error("lifecycle $stage"))
  @test_throws Exception SP.run_window_pipeline([1],i->fixturedata(i,3),read,(a,p,k)->0,(f,r,a)->nothing,
   f->(@test active[]==0;closed[]=true);options=streamopts(),actors,diagnostics=d,worker_hook=hook)
  assertsettled(d)
 end
 for stage in (:before_create,:before_start,:after_start)
  d=Dict{String,Any}()
  @test_throws Exception SP.run_window_pipeline([1],i->fixturedata(i,3),(r,k)->k,(a,p,k)->0,(f,r,a)->nothing,goodclose;
   options=streamopts(),actors,diagnostics=d,spawn_hook=(s,k,t)->(s==stage && k==2 && error("partial second worker")))
  assertsettled(d)
 end
 d=Dict{String,Any}();entered=Threads.Atomic{Bool}(false)
 read=(r,k)->begin
  if k==2
   timedwait(()->entered[],5)==:ok || error("analysis not started")
   error("higher read failure")
  end
  k
 end
 analyze=(a,p,k)->(entered[]=true;sleep(.02);error("lower analysis failure"))
 e=try
  SP.run_window_pipeline([1],i->fixturedata(i,3),read,analyze,(f,r,a)->nothing,goodclose;
   options=streamopts(),actors,diagnostics=d);nothing
 catch e;e end
 @test e isa SP.StreamFileError
 @test occursin("lower analysis failure",sprint(showerror,e))
 assertsettled(d)
end
@testset "completed checkpoint integrity survives later file failure" begin
 mktempdir() do dir
  d=Dict{String,Any}();actors=min(4,Threads.nthreads())
  publisher=(f,r,a)->begin
   out=joinpath(dir,string(f.analysis.item)*".cols")
   write_column_file(out,Dict("entry"=>Int64[1,2],"value"=>[1e16,-1e16]))
   SP.write_meta(out,"scientific-key";step="select")
  end
  @test_throws Exception SP.run_window_pipeline([1,2],i->fixturedata(i,3),
   (r,k)->(r.item==2 && k==2 && error("later file failed");k),(a,p,k)->0,publisher,goodclose;
   options=streamopts(stream_active_files=1),actors,diagnostics=d)
  @test SP.is_up_to_date(joinpath(dir,"1.cols"),"scientific-key")
  @test !ispath(joinpath(dir,"2.cols.meta.json"))
  @test !any(occursin(".tmp.",p) for p in readdir(dir))
  cols,_,_=read_column_file(joinpath(dir,"1.cols"));@test cols["value"]==[1e16,-1e16]
  assertsettled(d)
 end
end
end

@testset "explicit custom fallback and zero-work pool" begin
 raw=Dict("samples"=>[Dict("name"=>"f","kind"=>"data","files"=>["unused"],"format"=>"nanoaod")])
 cfg=parse_analysis(raw);sample=cfg.samples[1]
 if Threads.nthreads()>=3
  saved=SI.SOURCE_FORMATS["nanoaod"]
  try
   SI.SOURCE_FORMATS["nanoaod"]=x->error("must not run")
   @test SP.stream_selection_fallback(cfg,sample,nothing)=="replaced_readers"
  finally SI.SOURCE_FORMATS["nanoaod"]=saved end
  saved=copy(SP.HOOKS)
  try
   SP.HOOKS[:correct]=(identity,"custom")
   @test SP.stream_selection_fallback(cfg,sample,nothing)=="custom_hooks"
  finally empty!(SP.HOOKS);merge!(SP.HOOKS,saved) end
  @test SP.stream_selection_fallback(cfg,sample,:shape)=="shape_variations"
  d=Dict{String,Any}()
  @test isempty(SP.run_window_pipeline(Int[],identity,identity,identity,identity,identity;options=streamopts(),diagnostics=d))
  @test d["created_workers"]==0 && d["workers_joined"]
 end
 @test SI.builtin_source_readers()
end
@testset "decisive subtotal counterexample and empty/one-window science" begin
 cfg=parse_analysis(Dict("samples"=>[Dict("name"=>"x","kind"=>"mc","xsec_pb"=>1.,"files"=>["unused"])],
  "analysis"=>Dict("lumi_pb"=>1.),"weights"=>Dict("mc"=>["genWeight"]),
  "cuts"=>[Dict("name"=>"positive","expr"=>"x > 0")],
  "regions"=>[Dict("name"=>"inclusive","after"=>"positive","expr"=>"x > 0")]))
 sel=compile_selection(cfg,:mc);raw=Dict{String,Any}("genWeight"=>[1e16,1.,-1e16,3.,-2.],"x"=>ones(5))
 ref,cf=select_events(sel,raw,5;sample="x")
 unsafe=Cutflow(vcat("all",sel.cut_names))
 for range in (1:2,3:5)
  sub=Dict{String,Any}(key=>copy(v[range]) for (key,v) in raw)
  _,partial=select_events(sel,sub,length(range);sample="x")
  merge_cutflow!(unsafe,partial)
 end
 @test cf.sumw[1]==1.0
 @test unsafe.sumw[1]==2.0
 @test unsafe.sumw[1]!=cf.sumw[1] # the prohibited optimization is demonstrably wrong
 for ranges in ((1:5,),(1:2,3:5),(1:1,2:4,5:5))
  a=SP.StreamSelectionAnalysis(sel,"x")
  for (k,range) in enumerate(ranges)
   sub=Dict{String,Any}(key=>copy(v[range]) for (key,v) in raw)
   SP.analyze_stream_selection_window(a,(raw=sub,range=range,needed=nothing),k)
  end
  got=SP.finish_stream_selection!(a,5)
  @test isequal(got.meta,ref.meta)
  @test all(reinterpret(UInt8,got[key])==reinterpret(UInt8,ref[key]) for key in ref.order)
 end
 for n in (0,1)
  sub=Dict{String,Any}(key=>copy(v[1:n]) for (key,v) in raw)
  ref,_=select_events(sel,sub,n;sample="x");a=SP.StreamSelectionAnalysis(sel,"x")
  SP.analyze_stream_selection_window(a,(raw=sub,range=1:n,needed=nothing),1)
  got=SP.finish_stream_selection!(a,n)
  @test isequal(got.meta,ref.meta)
  @test all(reinterpret(UInt8,got[key])==reinterpret(UInt8,ref[key]) for key in ref.order)
 end
end

@testset "exact original basket-index eligibility" begin
 padded=(fBasketEntry=Int64[0,2,4,999],fEntries=4)
 @test SI.stream_basket_index(padded;basket_count=b->2)==(nothing,"unsupported_basket_index")
 @test SI.stream_basket_index((fBasketEntry=Int64[0,2,4],fEntries=4);basket_count=b->2)==((count=2,starts=[0,2,4],maskable=true),"")
 for count in (nothing,-1,true,1.5)
  @test SI.stream_basket_index(padded;basket_count=b->count)==(nothing,"unsupported_basket_index")
 end
 @test SI.stream_basket_index(padded;basket_count=b->throw(MethodError(-,(nothing,1))))==(nothing,"unsupported_basket_index")
 @test_throws ErrorException SI.stream_basket_index(padded;basket_count=b->error("corrupt count"))
 @test_throws InterruptException SI.stream_basket_index(padded;basket_count=b->throw(InterruptException()))
end
if Threads.nthreads()>=3
@testset "repeated interrupted join waits for HELD reader before close" begin
 gate=Channel{Nothing}(1);entered=Threads.Atomic{Bool}(false);finished=Threads.Atomic{Bool}(false)
 primary=ErrorException("controller primary remains identical");attempts=Ref(0);tasks=Task[];closed=Ref(false);d=Dict{String,Any}()
 read=(r,k)->try
  entered[]=true;take!(gate);k
 finally finished[]=true end
 waiter=task->begin
  attempts[]+=1
  if attempts[]<=2;throw(InterruptException());end
  # Always release the held worker even if a later test assertion throws.
  try
   @test !closed[]
   put!(gate,nothing)
   wait(task)
  finally
   finished[] || isready(gate) || put!(gate,nothing)
  end
 end
 control=(stage,value)->begin
  if stage==:after_admit
   timedwait(()->entered[],5)==:ok || error("held reader not started")
   throw(primary)
  end
 end
 err=try
  SP.run_window_pipeline([1],i->fixturedata(i,1),read,(a,p,k)->0,(f,r,a)->nothing,
   f->begin @test finished[];@test all(istaskdone,tasks);closed[]=true end;
   options=streamopts(),actors=3,diagnostics=d,controller_hook=control,waiter=waiter,
   spawn_hook=(s,k,t)->(s==:after_start && push!(tasks,t)))
  nothing
 catch e;e
 finally
  finished[] || isready(gate) || put!(gate,nothing)
 end
 @test err===primary
 @test finished[] && closed[] && all(istaskdone,tasks)
 @test d["cleanup_errors"]==2
 assertsettled(d)
end
@testset "ordinary stream failure preserves fallback checkpoints; fatal does NOT" begin
 mktempdir() do dir
  d=Dict{String,Any}();closed=Int[]
  publish=i->begin
   path=joinpath(dir,string(i)*".cols")
   write_column_file(path,Dict("entry"=>Int64[i]));SP.write_meta(path,"key-$i";step="select")
  end
  outcome=SP.capture_stream_file_failure() do
   SP.run_window_pipeline([1,2,3],i->i==3 ? "unsupported_format" : fixturedata(i,1),
    (r,k)->(r.item==2 && error("ordinary stream read failure");k),(a,p,k)->0,
    (f,r,a)->publish(f.analysis.item),f->push!(closed,f.analysis.item);
    options=streamopts(stream_active_files=1),actors=3,diagnostics=d)
  end
  @test outcome.failure isa SP.StreamFileError
  @test outcome.fallbacks==[(3,"unsupported_format")]
  @test SP.is_up_to_date(joinpath(dir,"1.cols"),"key-1")
  @test !ispath(joinpath(dir,"2.cols.meta.json"))
  @test sort(closed)==[1,2]
  err=try
   SP.finish_stream_selection_fallbacks(outcome.failure) do
    @test d["workers_joined"]
    # Include both statically classified and metadata-discovered fallbacks.
    for item in vcat([4],[first(x) for x in outcome.fallbacks]);publish(item);end
   end
   nothing
  catch e;e end
  @test err===outcome.failure
  @test SP.is_up_to_date(joinpath(dir,"3.cols"),"key-3")
  @test SP.is_up_to_date(joinpath(dir,"4.cols"),"key-4")
  @test occursin("stream file",sprint(showerror,err))
  @test !occursin("decode job",sprint(showerror,err))
  @test_throws SP.StreamFallbackFailure SP.finish_stream_selection_fallbacks(()->error("serial also failed"),outcome.failure)
  @test_throws InterruptException SP.finish_stream_selection_fallbacks(()->throw(InterruptException()),outcome.failure)
  assertsettled(d)
  for primary in (ErrorException("fatal controller"),InterruptException())
   attempted=Ref(false)
   err=try
    fatal=SP.capture_stream_file_failure() do
     SP.run_window_pipeline([3,1],i->i==3 ? "unsupported_format" : fixturedata(i,1),
      (r,k)->k,(a,p,k)->0,(f,r,a)->nothing,goodclose;options=streamopts(),actors=3,
      controller_hook=(s,v)->(s==:after_admit && throw(primary)))
    end
    SP.finish_stream_selection_fallbacks(()->(attempted[]=true),fatal.failure)
    nothing
   catch e;e end
   @test err===primary && !attempted[]
  end
 end
end
end

@testset "validated zero-tail physical prefix, original per-branch maskability" begin
 raw=Int64[0,2,4,0,0];saved=copy(raw)
 index,reason=SI.stream_basket_index((fBasketEntry=raw,fEntries=4);basket_count=b->2)
 @test isempty(reason) && !index.maskable && index.starts==[0,2,4]
 index.starts[2]=1;@test raw==saved
 @test SI.stream_basket_index((fBasketEntry=Int64[0,2],fEntries=4);basket_count=b->2)==(nothing,"unsupported_basket_index")
 for bad in ([0,2,4,0,1],[0,2,4,-1])
  @test SI.stream_basket_index((fBasketEntry=bad,fEntries=4);basket_count=b->2)==(nothing,"unsupported_basket_index")
 end
 for bad in ([1,2,4],[0,3,2,4],[0,2,5])
  @test_throws ErrorException SI.stream_basket_index((fBasketEntry=bad,fEntries=4);basket_count=b->length(bad)-1)
 end
 @test SI.stream_basket_index((fBasketEntry=[0,2,2,4],fEntries=4);basket_count=b->3)==(nothing,"empty_baskets")
 @test SI.stream_basket_index((fBasketEntry=[0,0,0],fEntries=0);basket_count=b->0)==((count=0,starts=[0],maskable=false),"")
end
using UnROOT
struct MaskabilityTestBranch
 baskets::Vector{Any}
end
UnROOT.basketarray(lb::MaskabilityTestBranch,k)=lb.baskets[k]
@testset "padded unmasked plus normal masked siblings reproduce ORIGINAL arrays" begin
 opts=streaming_selection_options(Dict());ranges=(1:2,3:4)
 baskets=[(lo=1,hi=2,bytes=64,decoded=64,keylen=16),(lo=3,hi=4,bytes=64,decoded=64,keylen=16)]
 flat=Any[Float32[10,20],Float32[30,40]]
 jagged=Any[[Float32[1,2],Float32[]],[Float32[3],Float32[4,5,6]]]
 offsets=[0,2,2,3,6]
 for needed in (trues(4),falses(4),Bool[true,false,false,false],Bool[false,true,false,true]),maskable in (false,true)
  starts=maskable ? [0,2,4] : nothing;effective=maskable ? needed : nothing
  expectflat=SI._read_flat(MaskabilityTestBranch(flat),4,2,starts,effective,Float32)
  expectjagged=maskable ? SI._read_jagged_masked(MaskabilityTestBranch(jagged),2,starts,effective,offsets,Float32,"p") : SI._read_jagged_all(MaskabilityTestBranch(jagged),4,2,Float32)
  outflat=Float32[];outjagged=Float32[];outoffs=Int[0];diag=Dict{String,Any}("unique_baskets"=>0,"repeated_baskets"=>0);seen=Set{Tuple{String,Int}}()
  for range in ranges
   localoffs=offsets[first(range):last(range)+1].-offsets[first(range)]
   brflat=(E=Float32,jagged=false,maskable=maskable,baskets=baskets)
   brjagged=(E=Float32,jagged=true,maskable=maskable,baskets=baskets)
   a=SI.read_stream_branch_owned(brflat,"f",range,opts,diag,seen;needed=needed[range],phase="post",basket_reader=(b,k)->flat[k])
   j=SI.read_stream_branch_owned(brjagged,"p",range,opts,diag,seen;needed=needed[range],offsets=localoffs,phase="post",basket_reader=(b,k)->jagged[k])
   append!(outflat,a);base=last(outoffs);append!(outjagged,j.content);append!(outoffs,j.offsets[2:end].+base)
  end
  @test reinterpret(UInt8,outflat)==reinterpret(UInt8,expectflat)
  @test reinterpret(UInt8,outjagged)==reinterpret(UInt8,expectjagged.content)
  @test outoffs==expectjagged.offsets
  @test diag["repeated_baskets"]==0
  !maskable && @test diag["padded_decoded_baskets"]==4
 end
 # Padded branch ignores needed/offsets exactly as old starts=nothing did.
 d=Dict{String,Any}("unique_baskets"=>0,"repeated_baskets"=>0);br=(E=Float32,jagged=true,maskable=false,baskets=baskets)
 got=SI.read_stream_branch_owned(br,"p",1:2,opts,d,Set{Tuple{String,Int}}();needed=[true],offsets=[-999],basket_reader=(b,k)->jagged[k])
 @test got.content==Float32[1,2] && got.offsets==[0,2,2]
 calls=Ref(0);normal=merge(br,(maskable=true,))
 for off in ([0,-1,2],[0,100,100])
  @test_throws ErrorException SI.read_stream_branch_owned(normal,"p",1:2,merge(opts,(stream_window_bytes=64,)),d,Set{Tuple{String,Int}}();needed=trues(2),offsets=off,basket_reader=(b,k)->(calls[]+=1;jagged[k]))
 end
 @test_throws ErrorException SI.read_stream_branch_owned(normal,"p",1:2,opts,d,Set{Tuple{String,Int}}();needed=trues(2),offsets=[0,100,100],basket_reader=(b,k)->(calls[]+=1;jagged[k]))
 @test calls[]==0 # rejected before native/large content allocation
end

@testset "target overshoot uses existing common cuts, not a whole-file shortcut" begin
 @test SI.stream_window_ranges([0,1000,4158,8316,12474,16632,20272],20272,20000)==[1:16632,16633:20272]
 @test SI.stream_window_ranges([0,1000,3693,7386,11079,14772,18465,20850],20850,20000)==[1:18465,18466:20850]
 @test SI.stream_window_ranges([0,25000],25000,20000)==[1:25000] # planner still refuses
 @test SI.stream_window_ranges([0,25000,30000],30000,20000)==[1:25000,25001:30000]
 @test SI.stream_window_ranges([0,1000,3765,7530,11295,15060,18825,22590,26355,30120,32853],32853,20000)==[1:22590,22591:32853]
 @test SI.stream_window_ranges([0],0,20000)==[1:0]
 @test SI.stream_window_ranges([0,10],10,20000)==[1:10]
end
