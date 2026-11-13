"""
    CorrectionSet

Collection of corrections loaded from a correctionlib schema-v2 JSON
document. `cset[name]` returns the [`Correction`](@ref) (or, if no
correction has that name, the [`CompoundCorrection`](@ref)) called `name`;
`keys(cset)` lists correction names and `compound_corrections(cset)` the
compound ones. Public fields: `schema_version`, `description`.
"""
struct CorrectionSet
    schema_version::Int
    description::String
    corrections::Dict{String,Correction}
    compound::Dict{String,CompoundCorrection}
end

const EVALUATOR_SCHEMA_VERSION = 2

function CorrectionSet(json::AbstractDict)
    sv = jint(json, :schema_version)
    sv > EVALUATOR_SCHEMA_VERSION && throw_correction_error(
        "Evaluator is designed for schema v$EVALUATOR_SCHEMA_VERSION and is not forward-compatible")
    sv < EVALUATOR_SCHEMA_VERSION && throw_correction_error(
        "Evaluator is designed for schema v$EVALUATOR_SCHEMA_VERSION and is not backward-compatible")
    description = jopt_string(json, :description, "")
    corrections = Dict{String,Correction}()
    for item in jarray(json, :corrections)
        isjsonobject(item) || throw_correction_error("Expected Correction object")
        c = Correction(item)
        haskey(corrections, c.name) && throw_correction_error("Duplicate Correction name: $(c.name)")
        corrections[c.name] = c
    end
    compound = Dict{String,CompoundCorrection}()
    items = jopt_array(json, :compound_corrections)
    if items !== nothing
        for item in items
            isjsonobject(item) || throw_correction_error("Expected CompoundCorrection object")
            c = CompoundCorrection(item, corrections)
            haskey(compound, c.name) && throw_correction_error("Duplicate CompoundCorrection name: $(c.name)")
            compound[c.name] = c
        end
    end
    return CorrectionSet(sv, description, corrections, compound)
end

function Base.getindex(cs::CorrectionSet, name::AbstractString)
    c = get(cs.corrections, name, nothing)
    c === nothing || return c
    cc = get(cs.compound, name, nothing)
    cc === nothing || return cc
    throw(KeyError(name))
end

Base.haskey(cs::CorrectionSet, name::AbstractString) = haskey(cs.corrections, name) || haskey(cs.compound, name)
Base.keys(cs::CorrectionSet) = sort!(collect(keys(cs.corrections)))
Base.length(cs::CorrectionSet) = length(cs.corrections)

function Base.show(io::IO, cs::CorrectionSet)
    print(io, "CorrectionSet(schema v", cs.schema_version, ", ", length(cs.corrections), " corrections, ",
          length(cs.compound), " compound)")
end
