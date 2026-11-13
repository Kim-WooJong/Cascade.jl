# Run recording-stub reference tests first, then exercise the unchanged production
# benchmark_trace/benchmark_span on both paths. JSON3 record serialization alone
# is a tiny stdlib-only fake; stage payloads/callees remain explicit recording fakes.
include("runtests.jl")
@eval P module JSON3
write(x::Nothing)="null"
write(x::Bool)=string(x)
write(x::Integer)=string(x)
write(x::AbstractString)=repr(x)
write(x::NamedTuple)="{"*join((write(String(k))*":"*write(v) for (k,v) in pairs(x)),",")*"}"
end
Base.include(P,H.src("Pipeline","benchmark_telemetry.jl"))
@testset "production span ON/OFF same stage results, types, bits, calls and failure finally" begin
 mktempdir() do dir
  trace_dir=mkdir(joinpath(dir,"trace"))
  for enabled in (false,true)
   withenv("CASCADE_BENCHMARK_TRACE_DIR"=>(enabled ? trace_dir : "")) do
    for lm in (H.Cascade.IO.LumiMask(1,10),nothing), hre in (false,true), co in (false,true)
     args,items=fixture(;lmask=lm,has_region_expr=hre,check_overlap=co)
     original=P.make_original_work(args...);unit=P.NoCheckpointFileWork(args...)
     for item in items
      P.FAIL[]=:none
      before=enabled ? (P.BENCHMARK_TRACE[]===nothing ? 0 : P.BENCHMARK_TRACE[].records) : 0
      a,la=runlog(original,item);b,lb=runlog(unit,item)
      @test sameresult(a,b) && la==lb
      @test count(x->x[1]===:select,lb)==1 && count(x->x[1]===:correct,lb)==1 && count(x->x[1]===:verify,lb)==1 && count(x->x[1]===:histogram,lb)==1
      if enabled
       @test P.BENCHMARK_TRACE[].records-before==12 # 3 begin/end pairs per old/new call
      else
       @test isempty(readdir(trace_dir))
      end
     end
    end
    args,items=fixture();unit=P.NoCheckpointFileWork(args...);original=P.make_original_work(args...)
    for fail in (:select,:shape,:tworesults,:correct,:verify,:histogram,:counts,:provenance,:json,:transport)
     P.FAIL[]=fail
     before=enabled ? P.BENCHMARK_TRACE[].records : 0
     a,la=runlog(original,items[1]);b,lb=runlog(unit,items[1])
     @test a isa Exception && typeof(a)===typeof(b) && sprint(showerror,a)==sprint(showerror,b)
     @test la==lb
     if enabled
      after=P.BENCHMARK_TRACE[].records
      expected=fail in (:select,:shape,:tworesults) ? 4 : fail in (:correct,:verify) ? 8 : 12
      @test after-before==expected
      lines=readlines(only(readdir(trace_dir;join=true)))[before+1:after]
      # Shape rejection is outside a completed select span; other failures are inside their span.
      failed=count(line->occursin("\"status\":\"failed\"",line),lines)
      @test failed==(fail in (:shape,:tworesults) ? 0 : 2)
     end
    end
    P.FAIL[]=:none
   end
  end
  trace=P.BENCHMARK_TRACE[]
  @test trace.pending==0
  records=readlines(only(readdir(trace_dir;join=true)))
  @test length(records)==trace.records
  @test count(l->occursin("\"event\":\"begin\"",l),records)==count(l->occursin("\"event\":\"end\"",l),records)
  @test all(l->occursin("\"resource_scope\":\"process_nonadditive\"",l),records)
  println("REAL_SPAN_RECORDS records=",trace.records," pending=",trace.pending)
 end
end
@testset "exact inserted generation-only named-stage hints accept real span without executing" begin
 text=read(H.src("Pipeline","precompile_pipeline.jl"),String)
 start=findfirst("    let kw = NamedTuple{(:sample, :chunk)",text).start
 stop=findnext("    # Opt-in stable selection kernels:",text,start).start
 before=copy(P.LOG);records=P.BENCHMARK_TRACE[].records
 Base.include_string(P,text[start:stop-1],"named_stage_hints.PRODUCTION.jl")
 @test P.LOG==before && P.BENCHMARK_TRACE[].records==records
 @test ccall(:jl_generating_output,Cint,())==0
end
println("NAMED_STAGES_TRACED_UNTRACED_COMPLETE")
