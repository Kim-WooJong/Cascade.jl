"""
    FitConfig

Resolved `[fit]` section of an analysis (see [`fit_config`](@ref)). Fields:

- `channels::Vector{FitChannel}`, `samples::Vector{FitSample}` (simulated
  processes), `data::Vector{String}` (store samples summed into the observation);
- `poi`, `poi_init`, `poi_bounds`, `signal` (fit samples scaled by the POI
  normfactor);
- `normsys::Vector{NormSysSpec}`;
- `histosys` (derive shape systematics from `<name>Up`/`<name>Down` variation
  histograms), `histosys_exclude`, `histosys_prune` (drop a histosys whose
  largest relative bin shift is `<= histosys_prune`);
- `staterror` (Barlow-Beeston-lite MC statistics from `sumw2`);
- `normsys_code`, `histosys_code` (interpolation codes);
- `impacts`, `upper_limit`, `significance`, `profile_interval`: optional
  outputs; `asimov`: fit the pre-fit Asimov dataset instead of the data.
"""
struct FitConfig
    channels::Vector{FitChannel}
    samples::Vector{FitSample}
    data::Vector{String}
    poi::String
    poi_init::Float64
    poi_bounds::Tuple{Float64,Float64}
    signal::Vector{String}
    normsys::Vector{NormSysSpec}
    histosys::Bool
    histosys_exclude::Vector{String}
    histosys_prune::Float64
    staterror::Bool
    normsys_code::Symbol
    histosys_code::Symbol
    impacts::Bool
    upper_limit::Bool
    significance::Bool
    profile_interval::Bool
    asimov::Bool
end
