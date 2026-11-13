include("traced.jl")
# Compare against the CURRENT canonical preimage, not only the older embedded
# anonymous-work oracle. Only its callable/helper identifiers are renamed.
baseline=read(joinpath(@__DIR__,"baseline_file_work.jl"),String)
baseline=replace(baseline,"NoCheckpointFileWork"=>"BaselineNoCheckpointFileWork",
 "no_checkpoint_file_item_type"=>"baseline_no_checkpoint_file_item_type",
 "no_checkpoint_file_work_hint_types"=>"baseline_no_checkpoint_file_work_hint_types")
Base.include_string(P,baseline,"no_checkpoint_file_work.CURRENT_PREIMAGE.jl")
@testset "current preimage callable exact outputs, errors and lowering" begin
 withenv("CASCADE_BENCHMARK_TRACE_DIR"=>"") do
  for lm in (H.Cascade.IO.LumiMask(1,10),nothing), hre in (false,true), co in (false,true)
   args,items=fixture(;lmask=lm,has_region_expr=hre,check_overlap=co)
   old=P.BaselineNoCheckpointFileWork(args...);new=P.NoCheckpointFileWork(args...)
   for item in items
    P.FAIL[]=:none
    a,la=runlog(old,item);b,lb=runlog(new,item)
    @test sameresult(a,b) && la==lb
   end
   for failure in (:select,:shape,:tworesults,:correct,:verify,:histogram,:counts,:provenance,:json,:transport)
    P.FAIL[]=failure
    a,la=runlog(old,items[1]);b,lb=runlog(new,items[1])
    @test typeof(a)===typeof(b)
    @test a isa Exception ? sprint(showerror,a)==sprint(showerror,b) : sameresult(a,b)
    @test la==lb
   end
   P.FAIL[]=:none
   item=P.no_checkpoint_file_item_type()
   boxes(f)=count("Core.Box",sprint(show,code_lowered(f,(item,))))
   @test boxes(new)==0 && boxes(new)<=boxes(old)
  end
 end
end
@testset "complete candidate syntax and no new world-age bypass" begin
 for name in ("no_checkpoint_file_work","precompile_pipeline")
  text=read(H.src("Pipeline",name*".jl"),String)
  ex=Meta.parseall(text)
  @test !any(x->x isa Expr && x.head in (:error,:incomplete),ex.args)
 end
 text=read(H.src("Pipeline","no_checkpoint_file_work.jl"),String)
 @test !occursin("invokelatest",text) && !occursin("Core.eval",text)
 # Integrated tree has other files; the exact two-file product delta is verified in the integration receipt.
 @test all(isfile(joinpath(H.CAND,"src","Pipeline",f)) for f in ("no_checkpoint_file_work.jl","precompile_pipeline.jl"))
end
println("NAMED_STAGES_FINAL_VALIDATION_COMPLETE")
