module TestModernCounting
using Test, TOML, SHA
# Stdlib-only harness: real Config types/helpers, no dependency install/cache load.
module Boundary
using TOML, SHA
const ROOT = normpath(joinpath(@__DIR__, "../.."))
for file in ("SampleConfig", "ObjectConfig", "CutConfig", "RegionConfig", "HistogramConfig", "VariationConfig", "TriggerConfig", "DataQualityConfig", "ShapeVariationConfig", "AnalysisConfig", "parse_binning", "substitute_paths", "resolve_config", "column_readers", "decode_options", "windowed_selection", "streaming_selection_options", "memory_handoff", "memoization_options", "checkpoint_options", "event_ranges", "validate_keys", "parse_analysis", "counting_readiness")
    include(joinpath(ROOT,"src/Config",file*".jl"))
end
# JSON3 string/scalar writing is stubbed ONLY in this portable boundary test.
module JSON3
write(x::AbstractString) = repr(x)
write(x) = string(x)
end
include(joinpath(ROOT,"src/Config/canonical_hash.jl"))
include(joinpath(ROOT,"src/Fit/counting_measurement.jl"))
include(joinpath(ROOT,"src/Fit/member_acceptance.jl"))
end
using .Boundary
const ROOT = normpath(joinpath(@__DIR__, "../.."))
@testset "independent modern counting / fail closed" begin
    raw = TOML.parsefile(joinpath(ROOT,"analyses/ttbar_emu/modern_counting.toml"))
    cfg = Boundary.parse_analysis(raw;dir=joinpath(ROOT,"analyses/ttbar_emu"))
    r = Boundary.counting_readiness(cfg)
    @test r["status"] == "blocked"
    @test length(r["blockers"]) == 6
    @test_throws ArgumentError Boundary.require_counting_ready(cfg)
    @test_throws ArgumentError Boundary.counting_measurement(cfg, [];observed=0,nuisances=Dict(),lumi_relative=0.014)
    @test length(cfg.regions)==1
    @test cfg.regions[1].name=="emu_ge2j"
    @test !any(x->occursin("btag",lowercase(x.cut)),cfg.objects)
    @test cfg.raw["counting"]["signal_samples"]==["TTto2L2Nu"]
    @test "TTtoLNu2Q" in cfg.raw["counting"]["background_samples"]
    @test Boundary.checkpoints_enabled(cfg) === false
    for p in ("baseline","sf","phase2","jer_candidate")
        old=Boundary.parse_analysis(TOML.parsefile(joinpath(ROOT,"analyses/ttbar_emu/analysis.toml"));profile=p)
        @test Boundary.counting_readiness(old)["status"]=="not_requested"
    end
    bad=deepcopy(raw);bad["counting"]["typo"]=true
    @test_throws ArgumentError Boundary.resolve_config(bad)
    mktempdir() do dir
        # Explicit synthetic fixture: this is not real calibration evidence.
        payload=joinpath(dir,"synthetic.txt");write(payload,"synthetic fixture only")
        for key in r["required_evidence"]
            path=joinpath(dir,key*".toml")
            open(path,"w") do io
                TOML.print(io,Dict("status"=>"validated","kind"=>key,"method"=>"synthetic unit fixture", "configuration_sha256"=>r["configuration_sha256"],"files"=>[Dict("path"=>payload,"sha256"=>bytes2hex(sha256(read(payload))))]))
            end
            cfg.raw["counting"]["required_evidence"][key]=path
        end
        @test Boundary.counting_readiness(cfg)["status"]=="ready"
        # All real MC names are present; zero-yield extras are deliberate fixtures.
        rows=[(name=s.name,sumw=s.name=="TTto2L2Nu" ? 100.0 : s.name=="TTtoLNu2Q" ? 20.0 : 0.0,sumw2=s.name=="TTto2L2Nu" ? 25.0 : s.name=="TTtoLNu2Q" ? 4.0 : 0.0) for s in cfg.samples if Boundary.is_mc(s)]
        templates=Dict(row.name=>(row.sumw*1.1,row.sumw*0.9) for row in rows)
        out=Boundary.counting_measurement(cfg,rows;observed=120,nuisances=Dict("shared"=>templates),lumi_relative=0.014)
        @test out.mu==1.0
        @test out.sigma_pb==924.0
        @test out.mc_stat_pb ≈ 924sqrt(0.0029)
        @test out.data_stat_pb ≈ 924sqrt(120)/100
        @test out.nuisance_shifts_pb["shared"][1] ≈ 924*((120-22)/110-1)
        @test out.lumi_shifts_pb[1] ≈ 924*((120-20*1.014)/(100*1.014)-1)
        @test_throws ArgumentError Boundary.counting_measurement(cfg,vcat(rows,rows[1:1]);observed=120,nuisances=Dict(),lumi_relative=0.014)
        @test_throws ArgumentError Boundary.counting_measurement(cfg,rows;observed=120.0,nuisances=Dict(),lumi_relative=0.014)
        @test_throws ArgumentError Boundary.counting_measurement(cfg,rows;observed=120,nuisances=Dict("lumi"=>templates),lumi_relative=0.014)
        @test_throws ArgumentError Boundary.counting_measurement(cfg,rows;observed=120,nuisances=Dict("partial"=>Dict()),lumi_relative=0.014)
        write(payload,"changed")
        @test Boundary.counting_readiness(cfg)["status"]=="blocked"
    end
    @test Boundary.member_acceptance([10.,20.],[100.,200.];decay_fraction=0.1061) ≈ [0.01061,0.01061]
    @test Boundary.member_acceptance([-10.],[-100.])==[0.1]
    @test_throws ArgumentError Boundary.member_acceptance([1.],[0.])
    @test_throws ArgumentError Boundary.member_acceptance([1.], [1.,2.])
    @test_throws ArgumentError Boundary.member_acceptance([1.], [1.];decay_fraction=2)
    # Read actual production pipeline prefix; stop must precede every data/output operation.
    pipeline=read(joinpath(ROOT,"src/Pipeline/run_pipeline.jl"),String)
    @test findfirst("require_counting_ready(cfg)",pipeline).start < findfirst("workdir =",pipeline).start
    @test occursin("require_counting_ready(cfg)",read(joinpath(ROOT,"src/Pipeline/run_no_checkpoints.jl"),String))
end
end
