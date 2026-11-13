# Synthetic correction sets, configurations and event tables for the weight tests.
using JSON3
using Cascade.Config, Cascade.IO, Cascade.Selection, Cascade.Systematics

"Category node over string keys."
fx_category(input, pairs) = Dict("nodetype" => "category", "input" => input,
                                 "content" => [Dict("key" => k, "value" => v) for (k, v) in pairs])

"2D (eta, pt) multibinning with flow = error."
fx_multibin(etas, pts, vals) = Dict("nodetype" => "multibinning", "inputs" => ["eta", "pt"],
                                    "edges" => [etas, pts], "content" => vals, "flow" => "error")

fx_var(name, type = "real") = Dict("name" => name, "type" => type)

# Lepton SF: syst in {nom, up, down}; eta edges [-3, 0, 3], pt edges [0, 50, 1000];
# value index: (eta bin - 1) * 2 + pt bin (row-major over eta, then pt).
const FX_LEP = Dict("nom" => [0.90, 0.95, 1.05, 1.10], "up" => [0.92, 0.97, 1.07, 1.13],
                    "down" => [0.88, 0.93, 1.03, 1.07])
# Working-point SF: wp in {A, B}, pt bins [0, 75, 1000]; syst in {sf, sfup, sfdown}.
const FX_WP = Dict("A" => Dict("sf" => [1.01, 1.02], "sfup" => [1.03, 1.04], "sfdown" => [0.99, 1.00]),
                   "B" => Dict("sf" => [0.97, 0.96], "sfup" => [0.99, 0.98], "sfdown" => [0.95, 0.94]))
# Pileup weight: ntrue bins [0, 20, 40, 100] (clamp), which in {nominal, up, down}.
const FX_PU = Dict("nominal" => [0.5, 1.0, 2.0], "up" => [0.6, 1.1, 2.2], "down" => [0.4, 0.9, 1.8])
# Integer-input weight: n in {0, 1, 2}.
const FX_INT = Dict(0 => 1.0, 1 => 1.5, 2 => 2.5)

"Write the synthetic correction set to `path`."
function write_fixture_set(path)
    lep = Dict("name" => "lep_sf", "version" => 1, "output" => fx_var("sf"),
               "inputs" => [fx_var("eta"), fx_var("pt"), fx_var("syst", "string")],
               "data" => fx_category("syst", [(k, fx_multibin([-3.0, 0.0, 3.0], [0.0, 50.0, 1000.0], v))
                                              for (k, v) in FX_LEP]))
    wp = Dict("name" => "wp_sf", "version" => 1, "output" => fx_var("sf"),
              "inputs" => [fx_var("year", "string"), fx_var("ValType", "string"), fx_var("WorkingPoint", "string"),
                           fx_var("pt")],
              "data" => fx_category("year", [("Y1", fx_category("ValType", [(vt,
                  fx_category("WorkingPoint", [(w, Dict("nodetype" => "binning", "input" => "pt",
                      "edges" => [0.0, 75.0, 1000.0], "content" => FX_WP[w][vt], "flow" => "error"))
                      for w in ("A", "B")])) for vt in ("sf", "sfup", "sfdown")]))]))
    pu = Dict("name" => "pu", "version" => 1, "output" => fx_var("w"),
              "inputs" => [fx_var("ntrue"), fx_var("which", "string")],
              "data" => fx_category("which", [(k, Dict("nodetype" => "binning", "input" => "ntrue",
                  "edges" => [0.0, 20.0, 40.0, 100.0], "content" => v, "flow" => "clamp")) for (k, v) in FX_PU]))
    nint = Dict("name" => "nint", "version" => 1, "output" => fx_var("w"), "inputs" => [fx_var("n", "int")],
                "data" => Dict("nodetype" => "category", "input" => "n",
                               "content" => [Dict("key" => k, "value" => v) for (k, v) in FX_INT]))
    open(path, "w") do io
        JSON3.write(io, Dict("schema_version" => 2, "corrections" => [lep, wp, pu, nint]))
    end
    return path
end

"Reference lepton SF (same binning as the fixture)."
function fx_lep(eta, pt, syst)
    ie = eta < 0 ? 1 : 2
    ip = pt < 50 ? 1 : 2
    return FX_LEP[syst][(ie - 1) * 2 + ip]
end
fx_wp(w, pt, vt) = FX_WP[w][vt][pt < 75 ? 1 : 2]
fx_pu(x, which) = FX_PU[which][x < 20 ? 1 : x < 40 ? 2 : 3]

"""
Configuration with objects muons/electrons, output variables for two muons and
one electron, and the given [corrections] table (sets.fx = `setpath`).
"""
function fixture_config(corr::AbstractDict; setpath, variations = Any[], extra_vars = Dict{String,Any}(),
                        extra_out = String[])
    vars = Dict{String,Any}("mu1_pt" => "muons.pt[1]", "mu1_eta" => "muons.eta[1]",
                            "mu2_pt" => "muons.pt[2]", "mu2_eta" => "muons.eta[2]",
                            "e1_pt" => "electrons.pt[1]", "e1_eta_sc" => "electrons.eta[1] + electrons.deltaEtaSC[1]",
                            "njet" => "length(jets)")
    merge!(vars, extra_vars)
    c = deepcopy(Dict{String,Any}(corr))
    c["sets"] = Dict{String,Any}("fx" => setpath)
    d = Dict{String,Any}(
        "analysis" => Dict{String,Any}("name" => "fx", "lumi_pb" => 1.0),
        "samples" => [Dict{String,Any}("name" => "mc1", "kind" => "mc", "xsec_pb" => 1.0, "format" => "cols",
                                       "files" => ["x.cols"]),
                      Dict{String,Any}("name" => "data1", "kind" => "data", "format" => "cols", "files" => ["y.cols"])],
        "objects" => [Dict{String,Any}("name" => "muons", "collection" => "Muon", "cut" => "pt > 10.0"),
                      Dict{String,Any}("name" => "electrons", "collection" => "Electron", "cut" => "pt > 10.0"),
                      Dict{String,Any}("name" => "jets", "collection" => "Jet", "cut" => "pt > 30.0")],
        "variables" => vars,
        "output" => Dict{String,Any}("columns" => vcat(["mu1_pt", "mu1_eta", "mu2_pt", "mu2_eta", "e1_pt", "e1_eta_sc", "njet"],
                                                       extra_out)),
        "weights" => Dict{String,Any}("mc" => ["genWeight"], "variations" => variations),
        "corrections" => c)
    return parse_analysis(d; dir = dirname(setpath))
end

"Event table of kept events with the output columns of `fixture_config`."
function fixture_table(; n = 6, entries = collect(2:2:2n))
    mu1_pt = [20.0, 60.0, 35.5, 80.0, 49.9, 50.0][1:n]
    mu1_eta = [-1.0, 0.5, 2.0, -2.5, 0.0, -0.1][1:n]
    mu2_pt = [15.0, 55.0, 70.0, 12.0, 45.0, 51.0][1:n]
    mu2_eta = [0.3, -0.3, -1.2, 1.9, 2.2, 0.7][1:n]
    e1_pt = [40.0, 74.9, 75.0, 120.0, 30.0, 90.0][1:n]
    e1_eta_sc = [0.1, -0.4, 1.1, -2.1, 0.0, 0.9][1:n]
    njet = [0.0, 1.0, 2.0, 1.0, 0.0, 2.0][1:n]
    weight = [1.5, -2.0, 0.75, 3.0, -1.25, 2.5][1:n]
    cols = Dict{String,Vector}("entry" => Vector{Int64}(entries), "stage" => fill(Int16(3), n), "weight" => weight,
                               "v:mu1_pt" => mu1_pt, "v:mu1_eta" => mu1_eta, "v:mu2_pt" => mu2_pt, "v:mu2_eta" => mu2_eta,
                               "v:e1_pt" => e1_pt, "v:e1_eta_sc" => e1_eta_sc, "v:njet" => njet)
    order = ["entry", "stage", "weight", "v:mu1_pt", "v:mu1_eta", "v:mu2_pt", "v:mu2_eta", "v:e1_pt", "v:e1_eta_sc", "v:njet"]
    return EventTable(cols, order, Dict{String,Any}())
end

"Source file (format cols) with an event-level Pileup_nTrueInt column of `nev` events."
function write_fixture_source(path; nev = 12)
    write_column_file(path, Dict{String,Any}("Pileup_nTrueInt" => Float32[3.5 * k for k in 1:nev],
                                             "genWeight" => ones(Float32, nev)); order = ["Pileup_nTrueInt", "genWeight"])
    return path
end
