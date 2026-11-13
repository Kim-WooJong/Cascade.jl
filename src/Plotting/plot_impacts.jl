"""
    plot_impacts(rows, outstem; poi="#mu", title="", max_rows=30, format=:both) -> NamedTuple

Ranking-style pull and impact plot (two native ROOT pads): `rows` (see
[`impact_rows`](@ref)) are drawn top-down in the given order, at most
`max_rows`. Left pad: pulls `(θ̂ - θ₀)/Δθ` with the postfit constraint as
horizontal error bar and reference lines at 0, ±1, ±2 (unconstrained parameters
have no pull point). Right pad: postfit (filled) and prefit (open) POI shifts
for the parameter moved up (red) and down (blue) by one standard deviation.
Returns `(; files, rows)` with the drawn rows.
"""
function plot_impacts(rows::AbstractVector, outstem::AbstractString; poi::AbstractString = "#mu",
                      title::AbstractString = "", max_rows::Integer = 30, format::Symbol = :both)
    isempty(rows) && throw(ArgumentError("no impact rows"))
    shown = collect(rows)[1:min(length(rows), max_rows)]
    n = length(shown)
    y = Float64.(n:-1:1)
    z(x) = isfinite(x) ? x : 0.0
    withpull = [i for i in 1:n if isfinite(shown[i].pull)]
    pmax = max(2.5, maximum((abs(shown[i].pull) + z(shown[i].constraint) for i in withpull); init = 0.0) * 1.1)
    ylim = (0.0, n + 1.0)
    names = [PlotText(-pmax - 0.08 * pmax, y[i], shown[i].name; ndc = false, size = 0.028, align = 32) for i in 1:n]
    vline(x, style) = PlotLine(x, 0.0, x, n + 1.0; color = "#888888", width = 1, style)
    pull_lines = [vline(0.0, 2), vline(-1.0, 3), vline(1.0, 3), vline(-2.0, 3), vline(2.0, 3)]
    hide = AxisStyle(label_color = "#FFFFFF", tick_length = 0.0)
    pull_series = isempty(withpull) ?
        [GraphSeries([0.0], [n + 0.5]; draw = :points, style = GraphStyle(color = "#FFFFFF", marker_size = 0.01))] :
        [GraphSeries([shown[i].pull for i in withpull], y[withpull]; xerrors = [z(shown[i].constraint) for i in withpull],
                     label = "Pull", style = GraphStyle(color = "#000000"))]
    pull_spec = GraphSpec(; xlabel = "(#hat{#theta}-#theta_{0})/#Delta#theta", ylabel = "", xlimits = (-pmax, pmax),
                          ylimits = ylim, legend = :none, yaxis = hide, lines = pull_lines, texts = names,
                          canvas = CanvasStyle(left_margin = 0.42, right_margin = 0.02))
    imax = maximum(max(abs(z(r.postfit_up)), abs(z(r.postfit_down)), abs(z(r.prefit_up)), abs(z(r.prefit_down)))
                   for r in shown)
    imax = imax > 0 ? 1.2 * imax : 1.0
    box(vals, color, alpha, label) = GraphSeries(zeros(n), y; xerrors = (low = max.(.-vals, 0.0), high = max.(vals, 0.0)),
                                                 yerrors = fill(0.3, n), errors = :boxes, label,
                                                 style = GraphStyle(color = color, fill_color = color, fill_alpha = alpha,
                                                                    marker_size = 0.01, line_width = 1))
    impact_series = [box([z(r.prefit_up) for r in shown], "#C5001A", 0.0, "Prefit +1#sigma"),
                     box([z(r.prefit_down) for r in shown], "#1F77B4", 0.0, "Prefit -1#sigma"),
                     box([z(r.postfit_up) for r in shown], "#C5001A", 0.6, "Postfit +1#sigma"),
                     box([z(r.postfit_down) for r in shown], "#1F77B4", 0.6, "Postfit -1#sigma")]
    impact_spec = GraphSpec(; xlabel = "#Delta#hat{" * poi * "}", ylabel = "", title, xlimits = (-imax, imax),
                            ylimits = ylim, legend = :none, yaxis = hide,
                            lines = [PlotLine(0.0, 0.0, 0.0, n + 1.0; color = "#888888", width = 1, style = 2)],
                            canvas = CanvasStyle(left_margin = 0.04, right_margin = 0.04))
    fig = PlotFigure([PlotPanel(pull_series, pull_spec), PlotPanel(impact_series, impact_spec)];
                     widths = [0.62, 0.38], size = (1100, max(400, 120 + 26 * n)))
    files = render_root(fig, outstem; format)
    return (; files, rows = shown)
end
