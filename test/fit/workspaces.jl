# Example pyhf-style workspaces shared by the fit tests.

_mod(name, type, data=nothing) = Dict{String,Any}("name" => name, "type" => type, "data" => data)
_sample(name, data, mods) = Dict{String,Any}("name" => name, "data" => data, "modifiers" => mods)
_ws(channels, obs, params; poi="mu") = Dict{String,Any}(
    "channels" => channels,
    "observations" => [Dict{String,Any}("name" => k, "data" => v) for (k, v) in obs],
    "measurements" => [Dict{String,Any}("name" => "meas",
                                        "config" => Dict{String,Any}("poi" => poi, "parameters" => params))],
    "version" => "1.0.0")

"Single-bin counting experiment: n observed, s signal (scaled by mu), b background."
ws_counting(; n=12.0, s=5.0, b=8.0) = _ws(
    [Dict{String,Any}("name" => "SR", "samples" => [
        _sample("signal", [s], [_mod("mu", "normfactor")]),
        _sample("background", [b], Any[])])],
    ["SR" => [n]], Any[])

"On/off problem: SR (n) and CR (m) share a free background normalisation kb; tau = bCR/bSR."
ws_onoff(; n=25.0, m=40.0, tau=4.0, s=10.0, b=10.0) = _ws(
    [Dict{String,Any}("name" => "SR", "samples" => [
         _sample("signal", [s], [_mod("mu", "normfactor")]),
         _sample("background", [b], [_mod("kb", "normfactor")])]),
     Dict{String,Any}("name" => "CR", "samples" => [
         _sample("background", [tau * b], [_mod("kb", "normfactor")])])],
    ["SR" => [n], "CR" => [m]],
    Any[Dict{String,Any}("name" => "kb", "bounds" => [[0.0, 100.0]])])

"Two-channel model using every supported modifier type."
function ws_full()
    sr = Dict{String,Any}("name" => "SR", "samples" => [
        _sample("signal", [2.0, 5.0, 8.0, 3.0], [
            _mod("mu", "normfactor"), _mod("lumi", "lumi"),
            _mod("sig_xs", "normsys", Dict("hi" => 1.05, "lo" => 0.93)),
            _mod("staterror_SR", "staterror", [0.3, 0.5, 0.6, 0.4])]),
        _sample("ttbar", [20.0, 15.0, 10.0, 5.0], [
            _mod("lumi", "lumi"), _mod("k_tt", "normfactor"),
            _mod("jes", "normsys", Dict("hi" => 1.08, "lo" => 0.95)),
            _mod("shape", "histosys", Dict("hi_data" => [21.0, 15.5, 9.5, 4.2],
                                            "lo_data" => [19.5, 14.2, 10.6, 5.5])),
            _mod("staterror_SR", "staterror", [1.0, 0.9, 0.8, 0.5])]),
        _sample("other", [5.0, 4.0, 3.0, 2.0], [
            _mod("lumi", "lumi"),
            _mod("other_xs", "normsys", Dict("hi" => 1.10, "lo" => 0.90)),
            _mod("staterror_SR", "staterror", [0.5, 0.4, 0.4, 0.3])])])
    cr = Dict{String,Any}("name" => "CR", "samples" => [
        _sample("ttbar", [50.0, 40.0, 30.0, 20.0], [
            _mod("lumi", "lumi"), _mod("k_tt", "normfactor"),
            _mod("jes", "normsys", Dict("hi" => 1.05, "lo" => 0.97)),
            _mod("cr_mc", "shapesys", [3.0, 3.0, 2.0, 2.0])]),
        _sample("other", [10.0, 8.0, 6.0, 4.0], [
            _mod("lumi", "lumi"),
            _mod("other_xs", "normsys", Dict("hi" => 1.10, "lo" => 0.90)),
            _mod("dd_shape", "shapefactor")])])
    return _ws([sr, cr], ["SR" => [30.0, 24.0, 22.0, 9.0], "CR" => [63.0, 50.0, 39.0, 26.0]],
               Any[Dict{String,Any}("name" => "lumi", "auxdata" => [1.0], "sigmas" => [0.017],
                        "inits" => [1.0], "bounds" => [[0.915, 1.085]]),
                   Dict{String,Any}("name" => "k_tt", "bounds" => [[0.0, 5.0]])])
end

"Model with an empty bin (masked staterror/shapesys parameters)."
ws_masked() = _ws(
    [Dict{String,Any}("name" => "SR", "samples" => [
        _sample("signal", [3.0, 0.0, 2.0], [_mod("mu", "normfactor")]),
        _sample("bkg", [10.0, 0.0, 6.0], [
            _mod("staterror_SR", "staterror", [1.0, 0.0, 0.8]),
            _mod("bkg_mc", "shapesys", [2.0, 0.0, 1.5])])])],
    ["SR" => [14.0, 0.0, 7.0]], Any[])

"Larger random model (2 channels x nb bins) for timing and cross-checks."
function ws_large(; nb=15, seed=20261104)
    rng = MersenneTwister(seed)
    chans = Any[]
    obs = Pair{String,Vector{Float64}}[]
    for (ci, cname) in enumerate(("CR", "SR"))
        sig = cname == "SR" ? [3.0 + 10 * exp(-((b - nb / 2) / 3)^2) for b in 1:nb] : fill(0.5, nb)
        samples = Any[_sample("signal", sig, [_mod("mu", "normfactor"), _mod("lumi", "lumi"),
                                              _mod("staterror_$cname", "staterror", 0.05 .* sig)])]
        total = copy(sig)
        for (si, sname) in enumerate(("bkg1", "bkg2", "bkg3"))
            nom = [(100.0 / si) * exp(-b / (5 + 3si)) + 2.0 for b in 1:nb]
            total .+= nom
            mods = Any[_mod("lumi", "lumi"), _mod("staterror_$cname", "staterror", 0.04 .* nom .+ 0.2)]
            for k in 1:5
                d = 0.02 + 0.06 * rand(rng)
                push!(mods, _mod("np_$k", "normsys", Dict("hi" => 1 + d, "lo" => 1 - 0.8d)))
            end
            for k in 1:3
                tilt = 0.05 * (rand(rng) - 0.5)
                up = nom .* [1 + tilt * (b - nb / 2) / nb + 0.03 for b in 1:nb]
                dn = nom .* [1 - 0.9 * tilt * (b - nb / 2) / nb - 0.025 for b in 1:nb]
                push!(mods, _mod("shape_$k", "histosys", Dict("hi_data" => up, "lo_data" => dn)))
            end
            si == 1 && push!(mods, _mod("k_bkg1", "normfactor"))
            push!(samples, _sample(sname, nom, mods))
        end
        push!(chans, Dict{String,Any}("name" => cname, "samples" => samples))
        push!(obs, cname => Float64.(round.(total .* (1 .+ 0.08 .* randn(rng)))))
    end
    return _ws(chans, obs, Any[Dict{String,Any}("name" => "lumi", "auxdata" => [1.0], "sigmas" => [0.02],
                                        "inits" => [1.0], "bounds" => [[0.9, 1.1]])])
end
