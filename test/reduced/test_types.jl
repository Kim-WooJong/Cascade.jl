module TestReducedTypes
using Test, Cascade
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..ReducedFixtures
@testset "primitive bitwise scalar jagged empty schema and validation" begin
    mktempdir() do dir
        p=setup(dir;theory=false)
        cols,meta,_=read_column_file(joinpath(dir,"input/a.cols"))
        names=String[]
        for T in (Bool,Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64,Float32,Float64)
            name="extra_"*string(T); push!(names,name)
            values=T<:AbstractFloat ? T[0.,-0.,1.,2.] : T[0,1,0,1]
            cols[name]=values
            jname="lists"*string(T); push!(names,jname)
            cols[jname]=Jagged([values[1:2],T[],values[3:3],T[]])
        end
        cols["bits32"]=reinterpret(Float32,UInt32[0x7fc00011,0x80000000,0x3f800000,0])
        cols["bits64"]=reinterpret(Float64,UInt64[0x7ff8000000000011,0x8000000000000000,0x3ff0000000000000,0])
        append!(names,["bits32","bits64"])
        write_column_file(joinpath(dir,"input/a.cols"),cols;meta)
        raw=Cascade.Pipeline.TOML.parsefile(p); raw["reduced_skim"]=Dict("mode"=>"legacy_eager","include"=>names); rewrite(p,raw)
        bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
        src=open_source("reduced_rntuple",joinpath(bundle,"signal/00000001.root"))
        got=read_columns(src,names)
        for name in names
            a=cols[name]; b=got[name]
            if a isa Jagged
                @test b.offsets==[0,2,2,3]
                @test eltype(a.content)==eltype(b.content)
                @test reinterpret(UInt8,a.content)==reinterpret(UInt8,b.content)
            else
                @test eltype(a)==eltype(b)
                @test reinterpret(UInt8,a[1:3])==reinterpret(UInt8,b)
            end
        end
        close_source(src)
        @test_throws Exception reduced_column_schema(Dict("x"=>["bad"]),1)
        @test_throws Exception reduced_column_schema(Dict("x"=>[1,2]),1)
        @test_throws Exception reduced_column_schema(Dict("X_pt"=>Jagged([1.,2.],[0,2,1,2])),3)
        @test_throws Exception reduced_column_schema(Dict("X_pt"=>Jagged([1.],[0,1]),"nX"=>UInt32[2]),1)
    end
end
end
