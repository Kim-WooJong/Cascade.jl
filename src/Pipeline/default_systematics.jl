"""
    default_systematics(ctx::StepContext, merged::HistogramStore) -> HistogramStore

Built-in `:systematics` hook: return merged histograms unchanged.
The pipeline reduces declared theory members before invoking this hook.
"""
default_systematics(ctx::StepContext, merged::HistogramStore) = merged
