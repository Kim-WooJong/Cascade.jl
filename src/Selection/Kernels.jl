"""
    Cascade.Selection.Kernels

Namespace in which compiled expression kernels are evaluated. Only the
whitelisted helpers below (plus `Base`) are visible to generated code.
"""
module Kernels
using ...Objects: deltaR, mass_massless, mass_massive, pair_pt, select_objects!, isolated_from, sort_objects!
end
