using Test,Cascade,TOML
using Cascade.IO,Cascade.Pipeline
include(joinpath(@__DIR__,"../reduced/fixtures.jl"))
using .ReducedFixtures
@testset "decode excludes shapes/cols and cache retains generation" begin
    for shapes in (false,true)
        mktempdir() do dir
            path=setup(dir;theory=false);raw=TOML.parsefile(path)
            shapes || (raw["shape_variations"]=Any[])
            raw["execution"]=Dict("decode_threads"=>1);rewrite(path,raw)
            work=joinpath(dir,"work")
            run_pipeline(RunOptions(path;workdir=work,steps=[:skim,:select]))
            entry=only(Cascade.Pipeline.read_skim(work,"signal")["files"])
            table=joinpath(work,"select","signal",entry["chunk"]*".cols")
            original=read(table);metadata=read(table*".meta.json");key=read_meta(table)["key"]
            raw["execution"]["decode_threads"]=16;rewrite(path,raw)
            result=run_pipeline(RunOptions(path;workdir=work,steps=[:select]))
            @test result[:select]["skipped"]==1
            @test read(table)==original && read(table*".meta.json")==metadata
            @test read_meta(table)["execution"]["requested_decode_threads"]==1
            run_pipeline(RunOptions(path;workdir=work,steps=[:select],force=true))
            m=read_meta(table)
            @test m["key"]==key
            @test read(table)==original
            @test m["execution"]["requested_decode_threads"]==16
            @test m["execution"]["decode_fallback"]==(shapes ? "shape_variations" : "unsupported_format")
            @test m["execution"]["stage_file_workers"]==1
        end
    end
end
include(joinpath(@__DIR__,"../source_reuse/test_source_reuse.jl"))
