module TestNanoAODReal
using Test, Cascade.IO
import UnROOT

# Needs gate data: CASCADE_REAL_DATA=1.
if get(ENV, "CASCADE_REAL_DATA", "0") == "1"
    @testset "NanoAODSource vs UnROOT LazyTree (real file)" begin
        dir = expanduser("~/nano_slim/mc/Run3Summer22NanoAODv12/TTto2L2Nu_TuneCP5_13p6TeV_powheg-pythia8/NANOAODSIM/*/*/*.root")
        path = first(expand_files([dir]))
        src = NanoAODSource(path)
        names = ["Electron_pt", "Electron_cutBased", "Muon_tightId", "Jet_jetId", "genWeight", "HLT_IsoMu24", "run"]
        cols = read_columns(src, names)
        t = UnROOT.LazyTree(src.file, "Events", names)
        n = nevents(src)
        @test n == length(t)
        ok = true
        for i in 1:n
            ev = t[i]
            for nm in names
                c = cols[nm]
                v = c isa Jagged ? collect(c[i]) : c[i]
                r = getproperty(ev, Symbol(nm))
                ok &= (v == (r isa AbstractVector ? collect(r) : r))
            end
            ok || break
        end
        @test ok
        # masked read: needed events identical, offsets canonical (from nElectron)
        needed = [isodd(i ÷ 3000) for i in 1:n]
        m = read_columns(src, ["Electron_pt", "Muon_tightId", "genWeight"]; needed)
        @test all(collect(m["Electron_pt"][i]) == collect(cols["Electron_pt"][i]) for i in 1:n if needed[i])
        @test m["Electron_pt"].offsets == cols["Electron_pt"].offsets
        @test all(m["genWeight"][i] == cols["genWeight"][i] for i in 1:n if needed[i])
        @test gen_weight_sum(src) > 0
        close_source(src)
    end
else
    @info "skipping real NanoAOD test (set CASCADE_REAL_DATA=1)"
end
end
