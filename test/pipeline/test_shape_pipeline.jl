module TestShapePipeline
# Shape systematics end to end on the synthetic analyses/shape_test definition:
# variation histograms equal a nominal run on inputs varied by hand, nominal
# results are unchanged by enabling variations, caching is keyed per sample.
using Test, Random, JSON3
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Histograms, Cascade.Pipeline, Cascade.Corrections
using Cascade.Systematics.Shape: jer_factors, JERShape
include(joinpath(@__DIR__, "..", "selection", "synthetic_events.jl"))
include(joinpath(@__DIR__, "shape_events.jl"))
using .SyntheticEvents, .ShapeEvents

const SRC = normpath(joinpath(@__DIR__, "..", "..", "analyses", "shape_test"))
const FILES = (("sigA", 2), ("bkgB", 2), ("dataEG", 1))
const MC = ("sigA", "bkgB")
const SHAPE_MARK = "# ---------------------------------------------------------------- shape systematics"

function setup(dir)
    for f in readdir(SRC)
        cp(joinpath(SRC, f), joinpath(dir, f))
    end
    rng = MersenneTwister(2026)
    ev = 1
    for (s, nf) in FILES, k in 1:nf
        c = add_shape_columns!(rng, synthetic_events(rng, 2500); first_event = ev)
        ev += 2500
        meta = s == "dataEG" ? Dict{String,Any}() : Dict{String,Any}("gen_weight_sum" => 1000.0 * k)
        write_column_file(joinpath(dir, "inputs", s, "f$k.cols"), c; meta)
    end
    return joinpath(dir, "analysis.toml")
end

"Write a variant of the analysis TOML (`f` edits the text)."
function variant(dir, name, f)
    p = joinpath(dir, name * ".toml")
    write(p, f(read(joinpath(dir, "analysis.toml"), String)))
    return p
end
no_shape(t) = t[1:first(findfirst(SHAPE_MARK, t))-1]
with_inputs(t, d) = replace(t, "inputs = \"inputs\"" => "inputs = \"$d\"")

"Copy the inputs to `dir/name`, applying `transform!(cols)` to MC files."
function varied_inputs(transform!, dir, name)
    for (s, nf) in FILES, k in 1:nf
        c, m, o = read_column_file(joinpath(dir, "inputs", s, "f$k.cols"))
        s == "dataEG" || transform!(c, s)
        write_column_file(joinpath(dir, name, s, "f$k.cols"), c; order = o, meta = m)
    end
end

"Scale jet pt/mass by per-jet factors `f` and propagate to PuppiMET (jets with unvaried pt > 15)."
function scale_jets!(c, f)
    pt = c["Jet_pt"]; m = c["Jet_mass"]; phi = c["Jet_phi"]
    newpt = Float32[Float32(Float64(pt.content[j]) * f[j]) for j in eachindex(pt.content)]
    newm = Float32[Float32(Float64(m.content[j]) * f[j]) for j in eachindex(m.content)]
    mpt = copy(c["PuppiMET_pt"]); mphi = copy(c["PuppiMET_phi"])
    for i in eachindex(mpt)
        mx = Float64(mpt[i]) * cos(Float64(mphi[i])); my = Float64(mpt[i]) * sin(Float64(mphi[i]))
        changed = false
        for j in pt.offsets[i]+1:pt.offsets[i+1]
            Float64(pt.content[j]) > 15.0 || continue
            d = Float64(newpt[j]) - Float64(pt.content[j])
            d == 0 && continue
            changed = true
            mx -= d * cos(Float64(phi.content[j])); my -= d * sin(Float64(phi.content[j]))
        end
        changed || continue
        mpt[i] = Float32(hypot(mx, my)); mphi[i] = Float32(atan(my, mx))
    end
    c["Jet_pt"] = Jagged(newpt, pt.offsets); c["Jet_mass"] = Jagged(newm, m.offsets)
    c["PuppiMET_pt"] = mpt; c["PuppiMET_phi"] = mphi
    return c
end

samples_json(work) = JSON3.read(read(joinpath(work, "merge", "samples.json"), String))[:samples]
merged(work) = read_store(joinpath(work, "merge", "histograms.json"))

"Every nominal MC histogram of `direct` equals `label` in `shape` (and the key sets agree)."
function same_as_label(shape, direct, label; samples = MC)
    ks = [k for k in keys(direct) if k.variation == NOMINAL && k.sample in samples]
    isempty(ks) && return false
    length(ks) == count(k -> k.variation == label && k.sample in samples, keys(shape)) || return false
    return all(shape[HistKey(k.region, k.sample, label, k.variable)] == direct[k] for k in ks)
end

@testset "shape variations end-to-end (synthetic)" begin
    mktempdir() do dir
        cfgp = setup(dir)
        work = joinpath(dir, "work")
        sm = run_pipeline(RunOptions(cfgp; workdir = work, steps = [:skim, :select, :correct, :histogram, :merge]))
        @test sm[:select]["run"] == 5
        st = merged(work)
        labels = Dict(s => sort(unique([k.variation for k in keys(st) if k.sample == s])) for (s, _) in FILES)
        @test labels["sigA"] == sort(["nominal", "JES_TotalUp", "JES_TotalDown", "JERUp", "JERDown",
                                      "MuScaleUp", "MuScaleDown"])
        @test labels["bkgB"] == sort(["nominal", "JES_TotalUp", "JES_TotalDown", "JERUp", "JERDown"])
        @test labels["dataEG"] == ["nominal"]
        k = HistKey("ge1j", "sigA", "nominal", "jet1_pt")
        @test st[k] != st[HistKey("ge1j", "sigA", "JES_TotalUp", "jet1_pt")]
        @test st[k] != st[HistKey("ge1j", "sigA", "JERUp", "jet1_pt")]

        # per-variation cutflows and yields
        info = samples_json(work)
        sh = info[:sigA][:shape]
        @test sort(String.(collect(keys(sh)))) == sort(setdiff(labels["sigA"], ["nominal"]))
        for (l, d) in pairs(sh)
            @test d[:cutflow][:n][1:2] == info[:sigA][:cutflow][:n][1:2]     # all, trigger: object-free
            @test isfile(joinpath(work, "merge", "cutflow_shape", "sigA", string(l, ".tsv")))
        end
        @test !haskey(info[:dataEG], :shape)
        @test isfile(joinpath(work, "merge", "shape_yields.tsv"))

        # nominal results are identical to a run without shape variations
        base = joinpath(dir, "work_base")
        run_pipeline(RunOptions(variant(dir, "base", no_shape); workdir = base,
                                steps = [:skim, :select, :correct, :histogram, :merge]))
        sb = merged(base)
        @test store_axis(sb, :variation) == ["nominal"]
        @test all(st[k] == sb[k] for k in keys(sb))
        ib = samples_json(base)
        @test all(info[Symbol(s)][:cutflow] == ib[Symbol(s)][:cutflow] for (s, _) in FILES)

        # JES up: nominal run on inputs with jets varied by hand
        jes = load_correctionset(joinpath(dir, "test_jerc.json"))["Test_JES_Total"]
        varied_inputs(dir, "in_jesup") do c, s
            pt = c["Jet_pt"]; eta = c["Jet_eta"]
            scale_jets!(c, [1.0 + evaluate(jes, Float64(eta.content[j]), Float64(pt.content[j])) for j in eachindex(pt.content)])
        end
        w1 = joinpath(dir, "work_jesup")
        run_pipeline(RunOptions(variant(dir, "jesup", t -> with_inputs(no_shape(t), "in_jesup")); workdir = w1,
                                steps = [:skim, :select, :correct, :histogram, :merge]))
        @test same_as_label(st, merged(w1), "JES_TotalUp")
        @test sh[:JES_TotalUp][:cutflow] == samples_json(w1)[:sigA][:cutflow]

        # muon scale down (sigA only)
        varied_inputs(dir, "in_mudown") do c, s
            s == "sigA" || return
            pt = c["Muon_pt"]; eta = c["Muon_eta"]
            c["Muon_pt"] = Jagged(Float32[Float32(Float64(pt.content[j]) * (abs(eta.content[j]) < 1.2 ? 0.99 : 0.98))
                                          for j in eachindex(pt.content)], pt.offsets)
        end
        w2 = joinpath(dir, "work_mudown")
        run_pipeline(RunOptions(variant(dir, "mudown", t -> with_inputs(no_shape(t), "in_mudown")); workdir = w2,
                                steps = [:skim, :select, :correct, :histogram, :merge]))
        @test same_as_label(st, merged(w2), "MuScaleDown"; samples = ("sigA",))

        # JER up (nominal unsmeared): smearing factors applied to the unvaried jets
        cfg = load_analysis(cfgp)
        jer = JERShape(only(filter(v -> v.kind === :jer, shape_variations(cfg))))
        varied_inputs(dir, "in_jerup") do c, s
            _, up, _ = jer_factors(jer, "Jet", c, nothing)
            scale_jets!(c, up)
        end
        w3 = joinpath(dir, "work_jerup")
        run_pipeline(RunOptions(variant(dir, "jerup", t -> with_inputs(no_shape(t), "in_jerup")); workdir = w3,
                                steps = [:skim, :select, :correct, :histogram, :merge]))
        @test same_as_label(st, merged(w3), "JERUp")

        # cached rerun; removing a variation of sigA reruns only sigA chunks
        sm2 = run_pipeline(RunOptions(cfgp; workdir = work, steps = [:skim, :select, :correct, :histogram, :merge]))
        @test all(v["run"] == 0 for v in values(sm2))
        nomu = variant(dir, "nomu", t -> t[1:first(findfirst("[[shape_variations]]\nname = \"MuScale\"", t))-1])
        sm3 = run_pipeline(RunOptions(nomu; workdir = work, steps = [:skim, :select, :correct, :histogram, :merge]))
        @test sm3[:select]["run"] == 2 && sm3[:select]["skipped"] == 3
        @test !any(k.variation == "MuScaleUp" for k in keys(merged(work)))

        # nominal JER smearing switch: nominal MC changes and equals a run on smeared inputs; data unchanged
        varied_inputs(dir, "in_jernom") do c, s
            nom, _, _ = jer_factors(jer, "Jet", c, nothing; nominal = true)
            scale_jets!(c, nom)
        end
        w4 = joinpath(dir, "work_jernom")
        run_pipeline(RunOptions(variant(dir, "jernom", t -> replace(t, "nominal = false" => "nominal = true"));
                                workdir = w4, steps = [:skim, :select, :correct, :histogram, :merge]))
        w5 = joinpath(dir, "work_jernom_direct")
        run_pipeline(RunOptions(variant(dir, "jernomd", t -> with_inputs(no_shape(t), "in_jernom")); workdir = w5,
                                steps = [:skim, :select, :correct, :histogram, :merge]))
        s4 = merged(w4); s5 = merged(w5)
        @test all(s4[k] == s5[k] for k in keys(s5))
        @test s4[k] != st[k]
        @test all(s4[x] == st[x] for x in keys(st) if x.sample == "dataEG")
    end
end
end
