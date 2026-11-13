module TestInputAliases
using Test, TOML, Cascade.Config, Cascade.Systematics.Shape
@testset "Payload input name aliases" begin
    dir=normpath(joinpath(@__DIR__,"..","..","analyses","shape_test"))
    original=load_analysis(joinpath(dir,"analysis.toml"))
    mktempdir() do tmp
        names=["JetEta","JetPt","Rho","systematic","GenPt","EventID","JER","JERSF"]
        mapping=Dict(n=>"custom_"*n for n in names)
        # Replace quoted field names only; formula expressions use indexed inputs.
        for file in ("test_jerc.json","test_jer_smear.json")
            text=read(joinpath(dir,file),String)
            for (a,b) in mapping; text=replace(text,"\"$a\""=>"\"$b\""); end
            write(joinpath(tmp,file),text)
        end
        raw=deepcopy(original.raw)
        for t in raw["shape_variations"]
            t["kind"] in ("jes","jer") || continue
            t["inputs"]=mapping
            for k in ("corrections","smear_file")
                haskey(t,k) && (t[k]=joinpath(tmp,basename(t[k])))
            end
        end
        cfg=parse_analysis(raw;dir)
        a=shape_variations(original);b=shape_variations(cfg)
        ja,jb=JESShape(a[1]),JESShape(b[1])
        ra,rb=JERShape(a[2]),JERShape(b[2])
        @test ja.uncertainty.inputs[1].name=="JetEta"
        @test jb.uncertainty.inputs[1].name=="custom_JetEta"
        @test ra.sf_has_pt==rb.sf_has_pt
        @test rb.resolution.inputs[1].name=="custom_JetEta"
        @test rb.smear.inputs[1].name=="custom_JetPt"
    end
end
end
