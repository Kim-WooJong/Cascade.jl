"""
    Cutflow(stages, columns, sumw; sumw2=zeros(size(sumw)), is_data=falses(length(columns)))
    Cutflow(stages, sumw::AbstractDict; sumw2=Dict(), columns=sort(collect(keys(sumw))), data=String[])

Selected yields per selection stage (rows) and sample or group (columns):
`sumw` and `sumw2` are `length(stages) × length(columns)` matrices; `is_data`
flags observed columns. The dictionary form takes one vector per column, a
missing `sumw2` entry means zero, and `data` names the observed columns.
"""
struct Cutflow
    stages::Vector{String}
    columns::Vector{String}
    sumw::Matrix{Float64}
    sumw2::Matrix{Float64}
    is_data::Vector{Bool}

    function Cutflow(stages::AbstractVector, columns::AbstractVector, sumw::AbstractMatrix{<:Real};
                     sumw2::AbstractMatrix{<:Real}=zeros(size(sumw)), is_data=falses(length(columns)))
        s, c = String.(stages), String.(columns)
        (isempty(s) || isempty(c)) && throw(ArgumentError("a cutflow needs stages and columns"))
        allunique(s) && allunique(c) || throw(ArgumentError("stage and column names must be unique"))
        size(sumw) == size(sumw2) == (length(s), length(c)) && length(is_data) == length(c) ||
            throw(ArgumentError("cutflow matrices must be stages × columns"))
        all(isfinite, sumw) && all(x -> isfinite(x) && x >= 0, sumw2) ||
            throw(ArgumentError("cutflow values must be finite with sumw2 >= 0"))
        return new(s, c, Float64.(sumw), Float64.(sumw2), Bool.(collect(is_data)))
    end
end

function Cutflow(stages::AbstractVector, sumw::AbstractDict; sumw2::AbstractDict=Dict{String,Vector{Float64}}(),
                 columns::AbstractVector=sort(collect(String.(keys(sumw)))), data::AbstractVector=String[])
    n = length(stages)
    w = zeros(n, length(columns)); v = zeros(n, length(columns))
    for (j, c) in enumerate(columns)
        haskey(sumw, c) || throw(ArgumentError("no cutflow values for $c"))
        length(sumw[c]) == n || throw(ArgumentError("cutflow of $c needs $n values"))
        w[:, j] .= sumw[c]
        haskey(sumw2, c) && (v[:, j] .= sumw2[c])
    end
    return Cutflow(stages, columns, w; sumw2=v, is_data=[c in data for c in columns])
end
