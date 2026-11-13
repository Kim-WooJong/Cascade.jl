module TestTheoryShape
using Test, TOML
using Cascade.Config, Cascade.IO, Cascade.Histograms, Cascade.Pipeline
using ..TestShapePipeline
const S=TestShapePipeline
@testset "theory with shape migration and scalar SF" begin
    mktempdir() do dir
        p=S.setup(dir)
        for (s,nf) in S.FILES, k in 1:nf
            file=joinpath(dir,"inputs",s,"f$k.cols")
            c,m,o=read_column_file(file)
            c["PSWeight"]=Jagged([[1.2,0.8] for _ in 1:length(c["genWeight"])])
            write_column_file(file,c;meta=m)
        end
        d=TOML.parsefile(p)
        d["hooks"]=Dict("correct"=>"Cascade.Systematics.apply_corrections")
        d["corrections"]=Dict("flat"=>[Dict("name"=>"sf","nominal"=>2.,"up"=>2.2,"down"=>1.8)])
        d["theory_weights"]=[Dict("name"=>"ISR","branch"=>"PSWeight","family"=>"ps","normalization"=>"relative",
            "reduction"=>"pair","indices"=>[1,2],"expected_length"=>2,"samples"=>["sigA"],"convention"=>"synthetic Up/Down")]
        open(io->TOML.print(io,d),p,"w")
        w=joinpath(dir,"theory");steps=[:skim,:select,:correct,:histogram,:merge,:systematics]
        run_pipeline(RunOptions(p;workdir=w,steps))
        a=read_store(joinpath(w,"systematics","templates.json"))
        delete!(d,"theory_weights");q=joinpath(dir,"baseline.toml");open(io->TOML.print(io,d),q,"w")
        bwork=joinpath(dir,"base");run_pipeline(RunOptions(q;workdir=bwork,steps))
        b=read_store(joinpath(bwork,"systematics","templates.json"))
        @test all(a[k]==b[k] for k in keys(b))
        @test any(k->k.variation=="JES_TotalUp",keys(a))
        for k in keys(b)
            k.sample=="sigA" && k.variation=="nominal" || continue
            @test a[k.region,k.sample,"ISRUp",k.variable].sumw≈b[k].sumw.*1.2
            @test a[k.region,k.sample,"ISRUp",k.variable].sumw2≈b[k].sumw2.*1.2^2
        end
        @test !any(k->occursin("ISR",k.variation)&&k.sample!="sigA",keys(a))
        @test !any(k->startswith(k.variation,"__theory_"),keys(a))
    end
end
end
