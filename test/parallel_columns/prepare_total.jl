using Cascade, TOML, JSON3, SHA, UnROOT, ROOTPlots, LinearAlgebra
using Cascade.Config
base=ENV["CASCADE_PARALLEL_CANDIDATE"]
project=normpath(joinpath(@__DIR__,"../.."))
source=joinpath(project,"analyses/ttbar_emu/analysis.toml")
cfg=load_analysis(source;profile="sf")
raw=deepcopy(cfg.raw)
raw["samples"]=[s for s in raw["samples"] if s["name"] in ("TTto2L2Nu","MuonEG")]
for s in raw["samples"]
    s["files"]=[ENV[s["name"]=="TTto2L2Nu" ? "CASCADE_PARALLEL_MC" : "CASCADE_PARALLEL_DATA"]]
end
raw["data_quality"]["golden_json"]=cfg.data_quality.golden_json
raw["histograms"]=[h for h in raw["histograms"] if h["name"]=="njet"]
raw["regions"]=[r for r in raw["regions"] if r["name"]=="emu_ge1j"]
for kind in ("object_sf","event_weight"), term in get(raw["corrections"],kind,Any[])
    pop!(term,"up",nothing); pop!(term,"down",nothing)
end
# The configured trigger placeholder is exactly unity in every direction.
# Omit this neutral term because the flat API requires up/down columns.
@assert all(t["nominal"]==t["up"]==t["down"]==1.0 for t in get(raw["corrections"],"flat",Any[]))
pop!(raw["corrections"],"flat",nothing)
plot=raw["plot"]
merge!(plot,Dict("formats"=>["png"],"variables"=>["njet"],"regions"=>["emu_ge1j"],
    "logy"=>String[],"tables"=>false,"cutflow"=>false,"postfit"=>false,"impacts"=>false,"band_normsys"=>false))
mkpath(joinpath(base,"configs"))
for width in (1,4)
    raw["execution"]=Dict("column_readers"=>width)
    path=joinpath(base,"configs","readers$width.toml")
    ispath(path) && error("validation config already exists")
    open(io->TOML.print(io,raw),path,"w")
    check=load_analysis(path)
    @assert isempty(shape_variations(check)) && !haskey(check.raw,"fit") && !haskey(check.raw,"theory_weights")
    @assert length(check.samples)==2 && length(check.histograms)==1
end
records=Dict("julia"=>string(VERSION),"threads"=>Threads.nthreads(),"blas_threads"=>BLAS.get_num_threads(),
    "unroot_source"=>pathof(UnROOT),"unroot_version"=>string(pkgversion(UnROOT)),
    "rootplots_source"=>pathof(ROOTPlots),"rootplots_version"=>string(pkgversion(ROOTPlots)),
    "manifest_sha256"=>bytes2hex(sha256(read(joinpath(project,"Manifest.toml")))),
    "root_available"=>ROOTPlots.root_available())
println(JSON3.write(records))
records["root_available"] || error("ordinary native renderer unavailable; no installation authorized")
