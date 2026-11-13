module TestSFProfileContract
using Test, TOML, Cascade, Cascade.Config, Cascade.Systematics

@testset "ttbar SF profile vs baseline" begin
    dir = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu"))
    base = load_analysis(joinpath(dir, "analysis.toml")).raw
    sf = load_analysis(joinpath(dir, "analysis.toml"); profile = "sf").raw
    added = ("corrections", "hooks")
    @test !any(haskey(base, k) for k in added)      # baseline stays genWeight-only
    for k in union(keys(base), keys(sf))
        k in added && continue
        if k == "analysis"
            core(d) = Dict(a => b for (a, b) in d if !(a in ("name", "workdir")))
            @test core(sf[k]) == core(base[k])
            @test sf[k]["workdir"] != base[k]["workdir"]
        elseif k in ("variables", "paths", "output")
            @test all(haskey(sf[k], a) && sf[k][a] == b for (a, b) in base[k])   # only additions
        else
            @test get(sf, k, nothing) == get(base, k, nothing)
        end
    end
    cfg = load_analysis(joinpath(dir, "analysis.toml"); profile = "sf")
    spec = parse_corrections(cfg)
    @test [t.name for t in spec.object_sfs] == ["muon_id", "muon_iso", "electron_reco", "electron_reco", "electron_id"]
    @test [t.name for t in spec.event_weights] == ["pileup"] && [t.name for t in spec.flat] == ["trigger_emu"]
    @test all(startswith(p, "/cvmfs/cms.cern.ch/rsync/cms-nanoAOD/jsonpog-integration/POG/") for p in values(spec.sets))
    @test Cascade.Pipeline.hook_for(cfg, :correct)[1] === apply_corrections
    # the real-valued object inputs resolve to declared output variables
    idx = output_column_index(cfg)
    for t in spec.object_sfs, k in ("eta", "pt")
        ex = object_expression(Cascade.Selection.parse_expression(t.inputs[k]), t.object, 1)
        @test haskey(idx, string(ex))
    end
    @test spec.object_sfs[3].when == "pt < 75.0" && spec.object_sfs[4].when == "pt >= 75.0"
end

@testset "ttbar trigger normsys fragment is explicitly unresolved" begin
    dir = normpath(joinpath(@__DIR__, "..", "..", "analyses", "ttbar_emu"))
    fit = TOML.parsefile(joinpath(@__DIR__, "fixtures", "trigger_normsys.toml"))["fit"]
    @test fit["histosys_exclude"] == ["trigger_emu"]
    n = only(fit["normsys"])
    @test n["name"] == "trigger_emu" && n["samples"] == ["all"]
    @test n["placeholder"] === true && n["size"] == 0.0
end

end
