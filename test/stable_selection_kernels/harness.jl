# Standalone stdlib-only harness for execution.stable_selection_kernels (B2b).
# REAL production source: Config structs/options/validate_keys, IO/Jagged.jl, the whole
# Objects module and the Selection compiler/runtime subset (translate, compile_kernel,
# StableKernel, compile_selection, apply_cuts, event_loop, prefix_pass,
# selection_context, staged_column_mask, select_events, VariableMemo, ...).
# Nothing is stubbed in the selection path; inputs are synthetic in-memory columns
# (no ROOT, no files). Also used as the body of the evidence-only B2bProbe package.
module StableKernelHarness
const ROOT = normpath(joinpath(@__DIR__, "../.."))
src(parts...) = joinpath(ROOT, "src", parts...)

module Config
const _src = parentmodule(@__MODULE__).src
for f in ("SampleConfig", "ObjectConfig", "CutConfig", "RegionConfig", "HistogramConfig", "VariationConfig",
          "TriggerConfig", "DataQualityConfig", "ShapeVariationConfig", "AnalysisConfig", "column_readers",
          "decode_options", "windowed_selection", "memory_handoff", "streaming_selection_options",
          "memoization_options", "checkpoint_options", "event_ranges", "validate_keys")
    include(_src("Config", f * ".jl"))
end
export AnalysisConfig, SampleConfig, ObjectConfig, CutConfig, RegionConfig, HistogramConfig, VariationConfig,
       TriggerConfig, DataQualityConfig
end # Config

module IO
const _src = parentmodule(@__MODULE__).src
for f in ("Jagged", "LumiMask", "lumimask_column")
    include(_src("IO", f * ".jl"))
end
export Jagged, LumiMask, lumimask_column, in_lumimask
end # IO

include(src("Objects", "Objects.jl"))

module Selection
using ..Config
using ..IO
import ..IO as EventIO
using ..Objects
const _src = parentmodule(@__MODULE__).src
for f in ("Kernels", "KernelContext", "CachedObjectBuffer", "ExpressionUsage", "VariableMemo", "parse_expression",
          "translate_expression", "compile_kernel", "StableKernel", "Cutflow", "merge_cutflow", "EventTable",
          "region_masks", "region_counts", "CompiledSelection", "SelectionProgress", "region_stages",
          "trigger_match", "trigger_paths", "trigger_column", "compile_selection", "apply_cuts", "event_loop", "prefix_pass", "selection_context",
          "staged_column_mask", "select_events")
    include(_src("Selection", f * ".jl"))
end
end # Selection

using .Config
using .IO: Jagged

# ---------------- deterministic fixture (no Random dependency) ----------------
mutable struct XorShift
    s::UInt64
end
function nextu!(r::XorShift)
    x = r.s
    x ⊻= x << 13; x ⊻= x >> 7; x ⊻= x << 17
    r.s = x
    return x
end
unif!(r) = Float64(nextu!(r) >> 11) / Float64(UInt64(1) << 53)

const FIXTURE_VARIABLES = Dict(
    "lead" => "jets.pt[1]",
    "sub" => "jets.pt[2]",
    "ht2" => "lead + sub",
    "drjj" => "deltaR(jets.eta[1], jets.phi[1], jets.eta[2], jets.phi[2])",
    "metsq" => "MET_pt^2 + MET_pt^3 / 1000.0 + MET_pt^-1",
    "ratio" => "MET_pt / MET_sumEt",
    "negz" => "-(MET_phi)",
    "pi_term" => "MET_phi * π",
    "ternary" => "MET_pt > 50.0 ? 1 : 2",
    "hexlit" => "Float64(nJet & 0x03) + 1.5f0")          # UInt8 and Float32 literals
# NB: integer literals wider than Int64 parse as @int128_str/@big_str macrocalls, which the
# unchanged translator rejects in BOTH modes (run2 evidence); they never reach a kernel.

"""Synthetic analysis covering objects+cleaning+sort, object deadlines, guarded indices,
inlined/memoized variables, literal_pow, comparison chains, ternaries, NaN/signed zero,
regions with early retention, histograms with when-guards, variations and outputs."""
function fixture_config(; stable::Bool = true, memo::Bool = false, lead_cut::Float64 = 40.0, extra_cuts = CutConfig[],
                        triggers::TriggerConfig = TriggerConfig(),
                        outputs = ["ratio", "negz", "pi_term", "ternary", "hexlit"], variables = FIXTURE_VARIABLES)
    objects = [ObjectConfig("electrons", "Electron", "pt > 20.0 && abs(eta) < 2.5", String[], 0.0, "pt"),
               ObjectConfig("jets", "Jet", "pt > 30.0 && abs(eta) < 2.4 && (jetId & 2) != 0", ["electrons"], 0.4, "pt")]
    cuts = vcat([CutConfig("trig", "trigger", :all),
                 CutConfig("runok", "run > 0", :data),
                 CutConfig("nele", "length(electrons) >= 1", :all),
                 CutConfig("njet", "length(jets) >= 2", :all),
                 CutConfig("lead", string("lead > ", repr(lead_cut), " && sub > 30.0"), :all),
                 CutConfig("chain", "0.0 <= MET_pt < 500.0", :all),
                 CutConfig("tern", "(MET_pt > 50.0 ? 1 : 0) == 1 || nJet > 3", :all)], extra_cuts)
    regions = [RegionConfig("SR", "lead", "drjj > 0.4"), RegionConfig("CR", "njet", "true"),
               RegionConfig("EARLY", "trig", "MET_pt > 10.0")]
    hists = [HistogramConfig("lead", [0.0, 50.0, 100.0], ["lead"], "length(jets) >= 1", String[], "lead"),
             HistogramConfig("met", [0.0, 100.0], ["MET_pt", "metsq"], "true", String[], "met"),
             HistogramConfig("drjj", [0.0, 5.0], ["drjj", "ht2"], "length(jets) >= 2", String[], "dr")]
    variations = [VariationConfig("scale", "1.0 + 0.1 * Float64(trigger)", "0.9")]
    raw = Dict{String,Any}("execution" => Dict{String,Any}("stable_selection_kernels" => stable, "memoize_variables" => memo))
    return AnalysisConfig("fixture", "/fixture.toml", "/", 1000.0, SampleConfig[], objects, Dict{String,String}(variables),
        cuts, regions, hists, ["genWeight", "puWeight"], String[], variations, triggers, DataQualityConfig(),
        outputs, "/wd", raw)
end

"""n synthetic events; n == 0 gives the zero-event typed schema (no data) used at image generation."""
function fixture_raw(n::Int; seed::UInt64 = 0x9e3779b97f4a7c15)
    r = XorShift(seed)
    jets = [Float32[] for _ in 1:n]; jeta = [Float32[] for _ in 1:n]; jphi = [Float32[] for _ in 1:n]; jid = [Int32[] for _ in 1:n]
    ept = [Float32[] for _ in 1:n]; eeta = [Float32[] for _ in 1:n]; ephi = [Float32[] for _ in 1:n]
    met = zeros(Float32, n); metphi = zeros(Float32, n); sumet = zeros(Float32, n)
    gw = zeros(Float64, n); pu = zeros(Float32, n); trig = fill(false, n); njet = zeros(Int32, n); run = zeros(Int32, n)
    for i in 1:n
        nj = Int(nextu!(r) % 5); ne = Int(nextu!(r) % 3)
        for _ in 1:nj
            push!(jets[i], Float32(10 + 140 * unif!(r))); push!(jeta[i], Float32(-3 + 6 * unif!(r)))
            push!(jphi[i], Float32(-3.14 + 6.28 * unif!(r))); push!(jid[i], Int32(nextu!(r) % 7))
        end
        for _ in 1:ne
            push!(ept[i], Float32(5 + 60 * unif!(r))); push!(eeta[i], Float32(-3 + 6 * unif!(r)))
            push!(ephi[i], Float32(-3.14 + 6.28 * unif!(r)))
        end
        met[i] = Float32(600 * unif!(r))
        metphi[i] = i % 7 == 0 ? (i % 14 == 0 ? -0.0f0 : 0.0f0) : Float32(-3 + 6 * unif!(r))
        sumet[i] = i % 11 == 0 ? 0.0f0 : Float32(1000 * unif!(r))
        i % 13 == 0 && (met[i] = 0.0f0; sumet[i] = 0.0f0)                 # 0/0 -> NaN ratio, 0^-1 -> Inf
        i % 17 == 0 && (met[i] = NaN32)                                     # NaN comparisons
        big = isodd(i) ? 1e16 : -1e16                                       # signed cancellation
        gw[i] = i % 5 == 0 ? big : (i % 9 == 0 ? -0.0 : (unif!(r) - 0.3) * 2)
        pu[i] = Float32(0.5 + unif!(r)); trig[i] = nextu!(r) % 4 != 0
        njet[i] = Int32(nj); run[i] = Int32(i % 19 == 0 ? 0 : 300000 + i)
    end
    return Dict{String,Any}("Jet_pt" => Jagged(jets), "Jet_eta" => Jagged(jeta), "Jet_phi" => Jagged(jphi),
        "Jet_jetId" => Jagged(jid), "Electron_pt" => Jagged(ept), "Electron_eta" => Jagged(eeta),
        "Electron_phi" => Jagged(ephi), "MET_pt" => met, "MET_phi" => metphi, "MET_sumEt" => sumet,
        "genWeight" => gw, "puWeight" => pu, "trigger" => trig, "nJet" => njet, "run" => run)
end

"""Generation-time record baked into the evidence probe image (type-level work only)."""
function generation_record()
    sel = Selection.compile_selection(fixture_config(; stable = true, memo = true), :mc)
    ctx = Selection.selection_context(fixture_raw(0), sel, sel.collections; n = 0)
    ok = Selection.precompile_stable_selection(sel, ctx)
    all(ok) || error("stable selection precompile failed: $(ok)")
    legacy = Selection.compile_selection(fixture_config(; stable = false, memo = true), :mc)
    return (sel_type = typeof(sel), ctx_type = typeof(ctx), legacy_cut_type = typeof(legacy.cuts[1]),
            generating = ccall(:jl_generating_output, Cint, ()) == 1, precompile_ok = ok)
end
end # StableKernelHarness
