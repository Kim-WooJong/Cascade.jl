"""
    checkpoints_enabled(raw_or_cfg) -> Bool

Execution-only switch `[execution] checkpoints` (strict Bool, default `true`).
`true` keeps the per-file skim/select/correct/histogram artifacts, cache keys and
resume behaviour unchanged. `false` requests one fresh, no-resume, in-memory full
chain (`Pipeline.run_no_checkpoints`): no per-file checkpoint is read or written
and only final outputs are published. Unsupported plans fail before data work or
directory writes. The value is never part of a scientific or cache key.
"""
function checkpoints_enabled(raw::AbstractDict)
    execution = get(raw, "execution", Dict())
    execution isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled = get(execution, "checkpoints", true)
    enabled isa Bool || throw(ArgumentError("execution.checkpoints must be boolean"))
    return enabled
end
checkpoints_enabled(cfg::AnalysisConfig) = checkpoints_enabled(cfg.raw)

"""Default-OFF skim-only TTree20 entry-count prefix; no-checkpoint configured-lumi NanoAOD only.
Other formats/modes and unsupported prefix schemas retain the ordinary nevents path.
"""
function lightweight_skim_metadata(raw::AbstractDict)
    e=get(raw,"execution",Dict())
    e isa AbstractDict || throw(ArgumentError("execution must be a table"))
    enabled=get(e,"lightweight_skim_metadata",false)
    enabled isa Bool || throw(ArgumentError("execution.lightweight_skim_metadata must be boolean"))
    return enabled
end
lightweight_skim_metadata(cfg::AnalysisConfig)=lightweight_skim_metadata(cfg.raw)
