"""Preload raw dependencies into one bounded cache, shrinking before selection if needed."""
function load_reduced_window(src, names, lo, hi, options; output_columns, variations)
    while true
        window = EventWindowSource(src, lo:hi, options)
        try
            raw = read_columns(window, names)
            estimate = 16 * Int128(window.metrics["live_window_bytes"]) +
                8 * Int128(nevents(window)) * (output_columns + 3) * variations +
                16 * Int128(options["target_shard_payload_bytes"]) + options["max_basket_bytes"]
            estimate <= options["max_buffer_bytes"] || error("window conservative buffer estimate exceeds max_buffer_bytes")
            return window, raw, Int(estimate)
        catch e
            message = sprint(showerror, e)
            shrinkable = occursin("window", message) && (occursin("max_window_bytes", message) || occursin("max_buffer_bytes", message))
            shrinkable && hi > lo || rethrow()
            hi = lo + (hi - lo) ÷ 2
        end
    end
end
