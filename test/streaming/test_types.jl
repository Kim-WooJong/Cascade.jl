module TestStreamingTypes
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline
using ..StreamingFixtures
@testset "all primitive raw bits survive window and jagged-empty shard boundaries" begin
mktempdir() do dir
    p=setup_stream(dir;theory=false,window=1,shard=1,target=10000)
    file=joinpath(dir,"input/a.cols"); cols,meta,_=read_column_file(file); names=String[]
    for T in (Bool,Int8,Int16,Int32,Int64,UInt8,UInt16,UInt32,UInt64,Float32,Float64)
        name="extra_"*string(T); push!(names,name)
        values=T<:AbstractFloat ? T[0.,-0.,1.,2.] : T[0,1,0,1]
        cols[name]=values; name="lists"*string(T); push!(names,name)
        cols[name]=Jagged([values[1:2],T[],values[3:3],T[]])
    end
    cols["bits32"]=reinterpret(Float32,UInt32[0x7fc00011,0x80000000,0x3f800000,0])
    cols["bits64"]=reinterpret(Float64,UInt64[0x7ff8000000000011,0x8000000000000000,0x3ff0000000000000,0])
    append!(names,["bits32","bits64"]); write_column_file(file,cols;meta)
    raw=TOML.parsefile(p); raw["reduced_skim"]["include"]=names; rewrite(p,raw)
    bundle=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=bundle)
    g=only(groups(bundle)); @test entries(g)==[1,2,3]
    for record in g["shards"]
        source=ReducedShardSource(joinpath(bundle,record["path"]))
        try
            got=read_columns(source,vcat(names,["event","cascade_source_entry"]))
            entry=only(got["cascade_source_entry"])
            @test only(got["event"])==cols["event"][entry]
            for name in names
                a=cols[name]; b=got[name]
                if a isa Jagged
                    @test eltype(a.content)==eltype(b.content)
                    @test b.offsets==[0,length(a[entry])]
                    @test reinterpret(UInt8,collect(a[entry]))==reinterpret(UInt8,b.content)
                else
                    @test eltype(a)==eltype(b)
                    @test reinterpret(UInt8,a[entry:entry])==reinterpret(UInt8,b)
                end
            end
        finally; close_source(source); end
    end
end
end
end
