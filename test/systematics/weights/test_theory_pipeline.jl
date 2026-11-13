# A two-file signed/zero-weight fixture deliberately makes eventwise extrema wrong.
using TOML
using Cascade.Pipeline, Cascade.Fit
function theory_identity_hook(ctx, store)
    @test !any(k->startswith(k.variation,"__theory_"),keys(store))
    store
end
@testset "theory full synthetic pipeline and cache" begin
    mktempdir() do dir
        for f in 1:2
            cols=Dict{String,Any}("genWeight"=>[2.,-1.,0.,3.],"x"=>[0.2,0.2,1.2,1.2],
                "V"=>Jagged([[2.,1.],[4.,1.],[9.,3.],[0.5,2.]]),
                "run"=>fill(Int32(1),4),"luminosityBlock"=>fill(Int32(1),4))
            write_column_file(joinpath(dir,"f$f.cols"),cols;meta=Dict("gen_weight_sum"=>4.))
        end
        raw=Dict{String,Any}("analysis"=>Dict("name"=>"theory","lumi_pb"=>8.),
            "samples"=>[Dict("name"=>"mc","kind"=>"mc","format"=>"cols","files"=>[joinpath(dir,"f*.cols")],"xsec_pb"=>1.),
                         Dict("name"=>"data","kind"=>"data","format"=>"cols","files"=>[joinpath(dir,"f1.cols")])],
            "weights"=>Dict("mc"=>["genWeight"]),"histograms"=>[Dict("name"=>"x","edges"=>[0.,1.,2.],"values"=>["x"])],
            "hooks"=>Dict("correct"=>"Cascade.Systematics.apply_corrections"),
            "corrections"=>Dict("flat"=>[Dict("name"=>"sf","nominal"=>2.,"up"=>2.2,"down"=>1.8)]),
            "theory_weights"=>[theory_fixture()],
            "fit"=>Dict("channels"=>[Dict("region"=>"signal","variable"=>"x")],"signal"=>["mc"],
                        "asimov"=>true,"impacts"=>false,"profile_interval"=>false,"staterror"=>false))
        p=joinpath(dir,"analysis.toml");open(io->TOML.print(io,raw),p,"w")
        work=joinpath(dir,"work");steps=[:skim,:select,:correct,:histogram,:merge,:systematics,:fit]
        sm=run_pipeline(RunOptions(p;workdir=work,steps))
        @test sm[:fit]["run"]==1
        st=read_store(joinpath(work,"merge","histograms_raw.json"))
        @test st["signal","mc","nominal","x"].sumw==[4.,12.]
        @test st["signal","mc","__theory_scale_1","x"].sumw==[0.,6.]
        @test st["signal","mc","__theory_scale_1","x"].sumw2==[256.,18.]
        @test st["signal","mc","sfUp","x"].sumw≈[4.4,13.2]
        @test !any(k->k.sample=="data" && k.variation!="nominal",keys(st))
        tpl=read_store(joinpath(work,"systematics","templates.json"))
        @test tpl["signal","mc","scaleUp","x"].sumw==[4.,24.]
        @test tpl["signal","mc","scaleDown","x"].sumw==[0.,6.]
        @test tpl["signal","mc","nominal","x"]==st["signal","mc","nominal","x"]
        ws=JSON3.read(read(joinpath(work,"fit","workspace.json"),String))
        mods=ws["channels"][1]["samples"][1]["modifiers"]
        m=only(filter(m->m["name"]=="scale",mods))
        @test Float64.(m["data"]["hi_data"])==[4.,24.]
        @test Float64.(m["data"]["lo_data"])==[0.,6.]
        sm=run_pipeline(RunOptions(p;workdir=work,steps));@test all(sm[s]["run"]==0 for s in steps)
        raw["theory_weights"][1]["indices"]=[2,1]
        open(io->TOML.print(io,raw),p,"w")
        sm=run_pipeline(RunOptions(p;workdir=work,steps))
        @test sm[:select]["run"]==0
        @test sm[:correct]["run"]==3 && sm[:systematics]["run"]==1 && sm[:fit]["run"]==1
        old=get(Cascade.Pipeline.HOOKS,:systematics,nothing)
        try
            register_hook!(:systematics,theory_identity_hook;id="theory_identity")
            sm=run_pipeline(RunOptions(p;workdir=work,steps=[:systematics]))
            @test sm[:systematics]["run"]==1
        finally
            old===nothing ? delete!(Cascade.Pipeline.HOOKS,:systematics) : (Cascade.Pipeline.HOOKS[:systematics]=old)
        end
    end
end
