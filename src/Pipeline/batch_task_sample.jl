"""Narrow a reduced worker's explicit input binding to its verified frozen file task."""
function batch_task_sample(sample::SampleConfig, path)
    sample.format == "reduced_rntuple" || return sample
    raw = deepcopy(sample.raw)
    raw["files"] = [String(path)]
    return SampleConfig(sample.name, sample.kind, [String(path)], sample.format,
        sample.xsec_pb, sample.branching_ratio, sample.stream, sample.group, raw)
end
