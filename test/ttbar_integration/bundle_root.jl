"""Use the explicitly bound immutable producer bundle when continuing a run."""
function bundle_root(area)
    bindings=joinpath(area,"reuse-bindings.json")
    return isfile(bindings) ? json(bindings)["bundle"] : joinpath(area,"bundle")
end
