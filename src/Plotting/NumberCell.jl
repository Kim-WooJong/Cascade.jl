"""
    NumberCell(value, high, low, digits, kind)

Numeric table cell rendered per output format by [`render_table`](@ref):
`kind = :value` (`value` only), `:uncertainty` (`± high`, or `+high / -low`
when the rounded sides differ) or `:value_uncertainty` (both). Non-finite
numbers are shown as `n/a`. Use [`value_cell`](@ref) and
[`uncertainty_cell`](@ref) to build cells.
"""
struct NumberCell
    value::Float64
    high::Float64
    low::Float64
    digits::Int
    kind::Symbol

    function NumberCell(value::Real, high::Real, low::Real, digits::Integer, kind::Symbol)
        kind in (:value, :uncertainty, :value_uncertainty) ||
            throw(ArgumentError("kind must be :value, :uncertainty or :value_uncertainty"))
        0 <= digits <= 12 || throw(ArgumentError("digits must be in 0:12"))
        return new(Float64(value), Float64(high), Float64(low), Int(digits), kind)
    end
end

"""
    value_cell(x; digits=1)
    uncertainty_cell(high, low=high; digits=1)

Shorthands for [`NumberCell`](@ref) values and uncertainties.
"""
value_cell(x::Real; digits::Integer=1) = NumberCell(x, NaN, NaN, digits, :value)
uncertainty_cell(high::Real, low::Real=high; digits::Integer=1) = NumberCell(NaN, high, low, digits, :uncertainty)
