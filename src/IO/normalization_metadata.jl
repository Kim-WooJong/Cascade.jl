"""
    normalization_metadata(src::AbstractEventSource) -> Dict

Inspect generator normalization provenance without changing `gen_weight_sum`.
Missing metadata is distinct from an available signed sum of zero. NanoAOD
inspection reads the configured Runs branch, never Events columns. Custom
sources may implement this method; the fallback explicitly remains unverified.
"""
normalization_metadata(::AbstractEventSource) = _normalization_record("unsupported", nothing,
    "custom source", nothing, "normalization provenance inspection is not implemented for this source")

function normalization_metadata(s::NanoAODSource)
    provenance = string(s.runs_tree, "/", s.gen_sumw)
    haskey(s.file, s.runs_tree) || return _normalization_record("missing", nothing, provenance, nothing, "Runs tree is absent")
    s.gen_sumw in keys(s.file[s.runs_tree]) ||
        return _normalization_record("missing", nothing, provenance, nothing, "generator sum branch is absent")
    try
        branch = UnROOT.LazyBranch(s.file, provenance)
        count = length(branch)
        (eltype(branch) <: Real && !(eltype(branch) <: Bool)) ||
            return _normalization_record("invalid", nothing, provenance, count, "expected a scalar numeric Runs branch")
        all(_normalization_number, branch) ||
            return _normalization_record("invalid", nothing, provenance, count, "nonfinite or nonnumeric Runs value")
        value = gen_weight_sum(s) # Preserve the established reduction, including its input precision.
        isfinite(value) || return _normalization_record("invalid", nothing, provenance, count, "nonfinite aggregate generator sum")
        return _normalization_record("available", value, provenance, count, "")
    catch e
        return _normalization_record("invalid", nothing, provenance, nothing, sprint(showerror, e))
    end
end

function normalization_metadata(s::ColumnFileSource)
    if haskey(s.meta, "gen_weight_sum")
        value = s.meta["gen_weight_sum"]
        provenance = "cols.meta.gen_weight_sum"
        _normalization_number(value) || return _normalization_record("invalid", nothing, provenance, 1, "invalid metadata generator sum")
        value = Float64(value)
        isfinite(value) || return _normalization_record("invalid", nothing, provenance, 1, "generator sum overflows Float64")
        return _normalization_record("available", value, provenance, 1, "")
    end
    provenance = "cols.column/" * s.gen_weight
    haskey(s.cols, s.gen_weight) || return _normalization_record("missing", nothing, provenance, nothing, "generator weight column and metadata sum are absent")
    values = s.cols[s.gen_weight]
    all(_normalization_number, values) || return _normalization_record("invalid", nothing, provenance, length(values), "expected finite scalar generator weights")
    value = gen_weight_sum(s)
    isfinite(value) || return _normalization_record("invalid", nothing, provenance, length(values), "nonfinite aggregate generator sum")
    return _normalization_record("available", value, provenance, length(values), "")
end

_normalization_number(x) = x isa Real && !(x isa Bool) && isfinite(x)
_normalization_record(status, value, provenance, entries, message) =
    Dict{String,Any}("status" => status, "value" => value, "provenance" => provenance,
                     "entries" => entries, "message" => message)
