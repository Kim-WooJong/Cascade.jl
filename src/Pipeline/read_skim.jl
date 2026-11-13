"""
    read_skim(workdir, sample) -> Dict{String,Any}

Load the skim index of a sample (file list with signatures, event counts and
generator-weight sums); errors if the skim step has not run.
"""
function read_skim(workdir, sample::AbstractString)
    p = skim_path(workdir, sample)
    isfile(p) || throw(ArgumentError("no skim artifact for sample $sample ($p); run the skim step first"))
    return _jsdict(JSON3.read(read(p, String)))
end
