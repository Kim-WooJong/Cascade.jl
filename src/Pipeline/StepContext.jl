"""
    StepContext

Everything a step (or a step hook) needs: the analysis `config`, the
`workdir`, the `step` name, the selected `samples` and the run `options`.
"""
struct StepContext
    config::AnalysisConfig
    workdir::String
    step::Symbol
    samples::Vector{SampleConfig}
    options::RunOptions
    input_scope::Any
end
StepContext(config, workdir, step, samples, options) = StepContext(config, workdir, step, samples, options, nothing)

"""
    CorrectionContext

Argument of the `:correct` hook for one chunk: `config`, `sample`, the source
file (`source_path`, opened with `IO.open_source(sample.format, source_path)`
if object columns are needed; `table["entry"]` gives the event indices), the
`table` (`Selection.EventTable`) of kept events and `variation`: `"nominal"`
or the shape-variation label (`<name>Up`/`<name>Down`) whose varied event
table is passed. Object columns read from the source file are unvaried; for
shape tables only the returned `"nominal"` weights are used. The built-in
correction hooks may receive an invocation-local lazy borrowed `source`; they
must not close it. Custom hooks retain `source === nothing` at this stage.
"""
struct CorrectionContext
    config::AnalysisConfig
    sample::SampleConfig
    source_path::String
    table::EventTable
    variation::String
    source::Any
end
CorrectionContext(config::AnalysisConfig, sample::SampleConfig, path::AbstractString, table::EventTable, variation::AbstractString) =
    CorrectionContext(config, sample, String(path), table, String(variation), nothing)

CorrectionContext(config::AnalysisConfig, sample::SampleConfig, source_path::AbstractString, table::EventTable) =
    CorrectionContext(config, sample, String(source_path), table, "nominal")
