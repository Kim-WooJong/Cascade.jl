# Gate-only focused integration; no Events processing and no production yields.
using Test, Cascade, TOML, SHA, JSON3
using Cascade.Config, Cascade.Histograms
const ROOT = normpath(joinpath(@__DIR__, "../.."))
const CONFIG = joinpath(ROOT,"analyses/ttbar_emu/modern_counting.toml")
@testset "full Cascade modern counting integration" begin
    @test realpath(pathof(Cascade)) == realpath(joinpath(ROOT,"src/Cascade.jl"))
    cfg = load_analysis(CONFIG)
    report = counting_readiness(cfg)
    @test report["status"] == "blocked"
    @test length(report["blockers"]) == 6
    @test Cascade.Pipeline.main(["check",CONFIG]) == 0
    # More-specific discovery trap proves public run does not discover inputs.
    @eval Cascade.IO begin
        const MODERN_DISCOVERY_CALLS = Ref(0)
        function expand_files(patterns::Vector{String})
            MODERN_DISCOVERY_CALLS[] += 1
            error("unexpected discovery after unresolved counting")
        end
    end
    @test_throws ErrorException Base.invokelatest(Cascade.IO.expand_files, String[])
    @test Cascade.IO.MODERN_DISCOVERY_CALLS[] == 1
    Cascade.IO.MODERN_DISCOVERY_CALLS[] = 0
    mktempdir() do dir
        work=joinpath(dir,"must-not-exist")
        err=joinpath(dir,"stderr.txt")
        rc=open(err,"w") do io
            redirect_stderr(io) do
                Base.invokelatest(Cascade.Pipeline.main, ["run",CONFIG,"--workdir",work,"--steps","skim,select,correct,histogram,merge"])
            end
        end
        @test rc == 1
        @test !ispath(work)
        text=read(err,String)
        @test occursin("counting blocked",text)
        @test all(k -> occursin(k*": evidence record missing",text),report["required_evidence"])
        @test Cascade.IO.MODERN_DISCOVERY_CALLS[] == 0
        println("PUBLIC_RUN_GATE rc=",rc," discovery_calls=",Cascade.IO.MODERN_DISCOVERY_CALLS[]," output_exists=",ispath(work)," missing_evidence=",length(report["blockers"]))
        println("PUBLIC_RUN_DIAGNOSTIC ",replace(text, '\n' => ' '))
        @test_throws ArgumentError Cascade.Fit.counting_from_store(cfg,"missing-hist.json","missing-samples.json";nuisances=Dict(),lumi_relative=0.014)
        # Synthetic evidence stays inside fixture and is never published as real.
        payload=joinpath(dir,"synthetic.txt");write(payload,"synthetic only")
        for key in report["required_evidence"]
            path=joinpath(dir,key*".toml")
            open(path,"w") do io
                TOML.print(io,Dict("status"=>"validated","kind"=>key,"method"=>"synthetic integration fixture", "configuration_sha256"=>report["configuration_sha256"],"files"=>[Dict("path"=>payload,"sha256"=>bytes2hex(sha256(read(payload))))]))
            end
            cfg.raw["counting"]["required_evidence"][key]=path
        end
        @test counting_readiness(cfg)["status"] == "ready"
        store=HistogramStore();store.meta["normalised"]=true;store.meta["lumi_pb"]=1210.0
        store.meta["counting_configuration_sha256"]=report["configuration_sha256"]
        records=Dict{String,Any}()
        for s in cfg.samples
            y=is_data(s) ? 30.0 : s.name=="TTto2L2Nu" ? 100.0 : s.name=="TTtoLNu2Q" ? 20.0 : 0.0
            v=is_data(s) ? y : s.name=="TTto2L2Nu" ? 25.0 : s.name=="TTtoLNu2Q" ? 4.0 : 0.0
            store.hists[HistKey("emu_ge2j",s.name,"nominal","njet")]=BinnedHist([1.5,1000000.0],[y],[v])
            records[s.name]=Dict("regions"=>Dict("emu_ge2j"=>Dict("cutflow_yield"=>y,"selected_event_count"=>Int(y))))
        end
        summary=Dict("lumi_pb"=>1210.0,"samples"=>records)
        out=Cascade.Fit.counting_from_store(cfg,store,summary;nuisances=Dict(),lumi_relative=0.014)
        @test out.mu == 1.0
        @test out.mc_stat_pb ≈ 924sqrt(0.0029)
        hp=joinpath(dir,"histograms.json");sp=joinpath(dir,"samples.json")
        write_store(hp,store);write(sp,JSON3.write(summary))
        @test Cascade.Fit.counting_from_store(cfg,hp,sp;nuisances=Dict(),lumi_relative=0.014).sigma_pb == 924.0
        delete!(store.meta,"lumi_pb")
        @test_throws ArgumentError Cascade.Fit.counting_from_store(cfg,store,summary;nuisances=Dict(),lumi_relative=0.014)
        store.meta["lumi_pb"]=1210.0
        delete!(store.meta,"counting_configuration_sha256")
        @test_throws ArgumentError Cascade.Fit.counting_from_store(cfg,store,summary;nuisances=Dict(),lumi_relative=0.014)
        store.meta["counting_configuration_sha256"]=report["configuration_sha256"]
        records["MuonEG"]["regions"]["emu_ge2j"]["cutflow_yield"]=31.0
        @test_throws ArgumentError Cascade.Fit.counting_from_store(cfg,store,summary;nuisances=Dict(),lumi_relative=0.014)
    end
end
println("FULLMODULE_INTEGRATION_COMPLETE no_events_processed=true no_production_yields=true")
