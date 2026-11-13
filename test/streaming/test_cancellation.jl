module TestStreamingCancellation
using Test, Cascade, TOML
using Cascade.IO, Cascade.Config, Cascade.Pipeline, Cascade.Histograms
using ..StreamingFixtures
@testset "declared partition cancellation error is contribution-scaled not falsely bit-exact" begin
mktempdir() do dir
    p=setup_stream(dir;theory=false,window=1,shard=2)
    f=joinpath(dir,"input/a.cols"); cols,meta,_=read_column_file(f)
    cols["genWeight"]=Float64[1e16,1,-1e16,1]
    cols["Jet_pt"]=Jagged(Float32[40,40,40,40],[0,1,2,3,4])
    write_column_file(f,cols;meta)
    raw=TOML.parsefile(p); delete!(raw,"shape_variations"); rewrite(p,raw)
    original=joinpath(dir,"original"); run_pipeline(RunOptions(p;workdir=original,steps=STEPS_STREAM))
    b=joinpath(dir,"bundle"); reduce_analysis(RunOptions(p);output_dir=b)
    work=joinpath(dir,"work"); run_pipeline(RunOptions(joinpath(b,"analysis.toml");workdir=work,steps=STEPS_STREAM))
    key=("signal","signal","nominal","pt")
    old=only(read_store(joinpath(original,"merge/histograms_raw.json"))[key...].sumw)
    new=only(read_store(joinpath(work,"merge/histograms_raw.json"))[key...].sumw)
    exact=sum(BigFloat.(cols["genWeight"]))
    contribution=sum(abs,BigFloat.(cols["genWeight"]))
    @test exact==2; @test old==1.; @test new==0.
    @test abs(BigFloat(new)-exact)/contribution<=big"2e-16"
    @test only(groups(b))["original_cutflows"]["nominal"]["sumw"]==[1.,1.]
    @test json(joinpath(work,"merge/samples.json")).samples.signal.gen_weight_sum==20.
    println("cancellation exact=2 legacy=",old," shard_partition=",new," abs_error=",Float64(abs(BigFloat(new)-exact))," contribution_scaled_error=",Float64(abs(BigFloat(new)-exact)/contribution))
end
end
end
