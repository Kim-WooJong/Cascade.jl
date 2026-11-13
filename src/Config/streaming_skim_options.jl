"""Validate independent window, physical-shard and resource budgets."""
function streaming_skim_options(d)
    values = get(d, "streaming", Dict())
    defaults = Dict("window_events" => 20_000, "target_shard_events" => 250_000,
        "target_shard_payload_bytes" => 32_000_000, "max_basket_bytes" => 64_000_000,
        "max_window_bytes" => 128_000_000, "max_buffer_bytes" => 1_024_000_000,
        "max_metadata_bytes" => 64_000_000)
    limits = Dict("window_events" => 1_000_000, "target_shard_events" => 1_000_000,
        "target_shard_payload_bytes" => 64_000_000, "max_basket_bytes" => 256_000_000,
        "max_window_bytes" => 256_000_000, "max_buffer_bytes" => 2_048_000_000,
        "max_metadata_bytes" => 64_000_000)
    out = Dict{String,Any}()
    for (key, default) in defaults
        value = get(values, key, default)
        value isa Integer && !(value isa Bool) && 0 < value <= limits[key] || error("invalid streaming budget $key")
        out[key] = Int(value)
    end
    out["max_window_bytes"] + out["target_shard_payload_bytes"] <= out["max_buffer_bytes"] || error("window/shard budgets exceed max_buffer_bytes")
    return out
end
