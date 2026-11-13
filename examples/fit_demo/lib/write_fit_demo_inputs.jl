"""
    write_fit_demo_inputs(dir; mu=1.2, seed=2026) -> Dict{String,Int}

Write the synthetic column files of `analyses/fit_demo` into `dir`
(`signal_mc/`, `background_mc/`, `pseudodata/`, two files each) and return
the number of events per sample. Event content: `mass` (Float32), `nJet`
(Int32) and, for simulation, `genWeight = 1` with `gen_weight_sum` in the file
meta. Signal: `nJet` ~ Poisson(3), `mass` = 20 + exponential (mean 80);
background: `nJet` ~ Poisson(0.8), `mass` ~ Gauss(91, 8) with a 20%
exponential tail. Simulation: 40 000 signal and 80 000 background events
(normalisation 0.25 each at 1 fb⁻¹ with σ = 10 pb and 20 pb). Pseudo-data:
`round(mu × 10 000 + sqrt(·) z)` signal and `round(20 000 + sqrt(·) z)`
background events (`z` standard normal), i.e. truth `mu` up to the
statistical fluctuation. Synthetic numbers, not a measurement.
"""
function write_fit_demo_inputs(dir::AbstractString; mu::Real = 1.2, seed::Integer = 2026)
    rng = MersenneTwister(seed)
    poisson(lambda) = (k = 0; p = exp(-lambda); s = p; u = rand(rng); while u > s; k += 1; p *= lambda / k; s += p; end; k)
    signal() = (Float32(20 + 80 * randexp(rng)), Int32(poisson(3.0)))
    background() = (Float32(rand(rng) < 0.8 ? 91 + 8 * randn(rng) : 20 + 60 * randexp(rng)), Int32(poisson(0.8)))
    function events(gen, n, weighted)
        ev = [gen() for _ in 1:n]
        cols = Dict{String,Any}("mass" => first.(ev), "nJet" => last.(ev))
        weighted && (cols["genWeight"] = ones(Float32, n))
        return cols
    end
    fluct(lambda) = round(Int, lambda + sqrt(lambda) * randn(rng))
    counts = Dict("signal_mc" => 40_000, "background_mc" => 80_000)
    for (name, gen) in (("signal_mc", signal), ("background_mc", background)), k in 1:2
        n = counts[name] ÷ 2
        write_column_file(joinpath(dir, name, "part$k.cols"), events(gen, n, true);
                          meta = Dict{String,Any}("gen_weight_sum" => Float64(n)))
    end
    ns, nb = fluct(mu * 10_000), fluct(20_000.0)
    for (k, (s, b)) in enumerate(((ns ÷ 2, nb ÷ 2), (ns - ns ÷ 2, nb - nb ÷ 2)))
        a, c = events(signal, s, false), events(background, b, false)
        write_column_file(joinpath(dir, "pseudodata", "part$k.cols"),
                          Dict{String,Any}(n => vcat(a[n], c[n]) for n in keys(a)))
    end
    counts["pseudodata"] = ns + nb
    counts["pseudodata_signal"] = ns
    return counts
end
