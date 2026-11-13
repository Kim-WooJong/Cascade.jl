function _export_column_count(value, label)
    value isa Integer && !(value isa Bool) && 0 <= value <= typemax(Int) || error("invalid cols compatibility declared $label")
    return Int128(value)
end
