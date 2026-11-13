"""
    Cascade.Corrections

Pure-Julia evaluator for the correctionlib JSON schema v2: correction sets
(`.json` / `.json.gz`), corrections and compound corrections with node types
Category, Binning, MultiBinning, Formula (TFormula subset), FormulaRef,
Transform and HashPRNG. Semantics (bin lookup, flow, formula grammar and
math, HashPRNG generator, JSON number conversion) follow correctionlib 2.8.

    cset = load_correctionset("electron.json.gz")
    c = cset["Electron-ID-SF"]
    sf = evaluate(c, "2022Re-recoBCD", "sf", "Tight", 1.2, 35.0)      # scalar
    sfs = evaluate(c, "2022Re-recoBCD", "sf", "Tight", etas, pts)     # vectorized
    evaluate!(out, c, "2022Re-recoBCD", "sf", "Tight", etas, pts)     # in place
"""
module Corrections

using CodecZlib

include("errors.jl")
include("read_json.jl")
include("json_access.jl")
include("variable.jl")
include("node_ref.jl")
include("vals.jl")
include("bin_axis.jl")
include("formula_math.jl")
include("erf.jl")
include("formula_ast.jl")
include("formula_parser.jl")
include("binning.jl")
include("multibinning.jl")
include("string_lookup.jl")
include("category.jl")
include("formula_node.jl")
include("transform.jl")
include("xxhash64.jl")
include("pcg32.jl")
include("hashprng.jl")
include("node_tree.jl")
include("build_node.jl")
include("remap_inputs.jl")
include("correction.jl")
include("compound_correction.jl")
include("correction_set.jl")
include("compound_corrections.jl")
include("load_correctionset.jl")
include("make_vals.jl")
include("evaluate.jl")
include("evaluate_columns.jl")

export CorrectionSet, Correction, CompoundCorrection, Variable, CorrectionError
export load_correctionset, parse_correctionset, compound_corrections, evaluate, evaluate!

end # module
