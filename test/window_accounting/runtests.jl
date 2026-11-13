using Test
const ROOT=normpath(joinpath(@__DIR__,"../.."))
@testset "candidate syntax" begin
 for (root,ds,fs) in walkdir(joinpath(ROOT,"src")), f in fs
  endswith(f,".jl") || continue
  @test Meta.parseall(read(joinpath(root,f),String);filename=f) isa Expr
 end
end
@testset "R21 regression and accounting" begin
 include("../windowed_reusable_decoder/test_buffer_reuse.jl")
 include("science_cases.jl")
end
@testset "accounting default OFF/config/profiles" begin
 @test !RWH.reuse_window_accounting(Dict())
 cfg=Dict("execution"=>Dict("windowed_selection"=>true,"windowed_reusable_decoder"=>true,"reuse_window_buffers"=>true,"reuse_window_accounting"=>true))
 @test RWH.validate_keys(cfg) === cfg
 @test RWH.reuse_window_accounting(cfg)
 for x in (0,1,"true",nothing)
  @test_throws ArgumentError RWH.validate_keys(Dict("execution"=>Dict("reuse_window_accounting"=>x)))
 end
 @test_throws ArgumentError RWH.reuse_window_accounting(Dict("execution"=>Dict("reuse_window_accounting"=>true)))
 @test_throws ArgumentError RWH.validate_keys(Dict("execution"=>cfg["execution"],"profiles"=>Dict("off"=>Dict("execution"=>Dict("reuse_window_buffers"=>false)))))
end
function charges(pool,raw,wc,needed)
 p=pool.progress; w=pool.accounting
 pool.accounting=nothing
 old=RWH.reusable_window_bytes(raw,p,wc,needed;buffer_reuse=pool)
 pool.accounting=w
 new=RWH.reusable_window_bytes(raw,p,wc,needed;buffer_reuse=pool)
 @test new >= old
 @test w.used==0
 return old,new
end
@testset "accounting aliases/capacity/growth/overflow" begin
 sel=RWH.object_selection(zeros(Int,3));pool=RWH.WindowBufferReuse(sel,4096,[8192,8192]);p=pool.progress
 pool.accounting=RWH.WindowAccounting(128)
 for n in (0,1,4096,7,0,4096)
  RWH.reset_window_buffers!(pool,sel,Dict{String,Any}(),n)
  off=collect(0:n);counts=fill(Int32(1),n)
  raw=Dict{String,Any}("nJ"=>counts,"J_pt"=>RWH.Jagged(ones(n),off),"J_eta"=>RWH.Jagged(ones(n),off))
  wc=(counts=Dict{String,Any}("nJ"=>counts),offsets=Dict("nJ"=>off));p.offsets["J"]=off
  old,new=charges(pool,raw,wc,p.needed)
  resize!(p.objs.j.data,8192); fill!(p.objs.j.data,1)
  @test charges(pool,raw,wc,p.needed)==(old,new) # fixed capacity, growth already reserved
  raw["extra"]=ones(1000)
  @test last(charges(pool,raw,wc,p.needed))>=new+8000
  delete!(raw,"extra")
  copied=copy(off);raw["J_eta"]=RWH.Jagged(ones(n),copied)
  @test last(charges(pool,raw,wc,p.needed))>=new
  sizehint!(counts,10000); resize!(counts,0)
  @test last(charges(pool,raw,wc,p.needed))>=new
 end
 # Object-index growth remains checked after selection even with A disabled.
 plain=RWH.SelectionProgress(sel,Dict{String,Any}(),1)
 before=RWH.reusable_window_bytes(plain.raw,plain)
 resize!(plain.objs.j.data,8192);fill!(plain.objs.j.data,1)
 @test RWH.reusable_window_bytes(plain.raw,plain)>before
 @test_throws OverflowError RWH.WindowAccounting(typemax(Int))
 pool.accounting=RWH.WindowAccounting(0)
 @test_throws ErrorException RWH.reusable_window_bytes(Dict{String,Any}("x"=>ones(1)),p;buffer_reuse=pool)
 @test pool.accounting.used==0
 pool.accounting=RWH.WindowAccounting(128)
 @test_throws ErrorException RWH.reusable_window_bytes(Dict{String,Any}("x"=>["bad"]),p;buffer_reuse=pool)
 @test pool.accounting.used==0
end
include("measure.jl")
