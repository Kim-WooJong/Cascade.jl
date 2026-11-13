"""
    region_masks(table::EventTable) -> Dict{String,BitVector}

Actual selected-event membership per region, including its optional expression.
Older tables without region-mask columns retain their sequential-stage meaning.
"""
function region_masks(table::EventTable)
    stages = table.meta["region_stage"]
    columns = get(table.meta, "region_columns", Dict{String,String}())
    return Dict{String,BitVector}(String(name) =>
        (haskey(columns, name) ? BitVector(table[String(columns[name])] .!= 0) :
         BitVector(table["stage"] .>= Int(stage))) for (name, stage) in stages)
end
