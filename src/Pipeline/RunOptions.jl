"""
    RunOptions(config; steps = copy(STEPS), samples = String[], force = false,
               workdir = "", max_files = 0)

Options of one pipeline run. `samples` empty = all samples. `workdir` empty =
`analysis.workdir` from the config (relative to the current directory).
`max_files > 0` limits the number of files per sample (quick tests).
"""
Base.@kwdef struct RunOptions
    config::String
    profile::String = ""
    steps::Vector{Symbol} = copy(STEPS)
    samples::Vector{String} = String[]
    force::Bool = false
    workdir::String = ""
    max_files::Int = 0
end

RunOptions(config::AbstractString; kw...) = RunOptions(; config = String(config), kw...)
