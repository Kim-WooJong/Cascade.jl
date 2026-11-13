module TestColumnPipelineGuards
using Test, Cascade, TOML
using Cascade.IO, Cascade.Pipeline
include(joinpath(@__DIR__,"../reduced/fixtures.jl"))
using .ReducedFixtures
@testset "cols/shapes fallback and cached generation metadata" begin
    for shapes in (false,true)
        mktempdir() do dir
            path=setup(dir;theory=false)
            raw=TOML.parsefile(path)
            shapes || (raw["shape_variations"]=Any[])
            raw["execution"]=Dict("column_readers"=>1); rewrite(path,raw)
            work=joinpath(dir,"work")
            run_pipeline(RunOptions(path;workdir=work,steps=[:skim,:select]))
            entry=only(Cascade.Pipeline.read_skim(work,"signal")["files"])
            table=joinpath(work,"select","signal",entry["chunk"]*".cols")
            old=read(table); metadata=read(table*".meta.json")
            key=read_meta(table)["key"]
            raw["execution"]["column_readers"]=4; rewrite(path,raw)
            result=run_pipeline(RunOptions(path;workdir=work,steps=[:select]))
            @test result[:select]["skipped"]==1
            @test read(table)==old && read(table*".meta.json")==metadata
            @test read_meta(table)["execution"]["requested_readers"]==1
            run_pipeline(RunOptions(path;workdir=work,steps=[:select],force=true))
            m=read_meta(table)
            @test m["key"]==key
            @test read(table)==old
            @test m["execution"]["requested_readers"]==4
            @test m["execution"]["effective_readers"]==1
            @test m["execution"]["fallback"]==(shapes ? "shape_variations" : "unsupported_format")
        end
    end
end
end
