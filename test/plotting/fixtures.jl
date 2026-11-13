# Hand-checkable synthetic templates shared by the plotting tests.
# Sample A: nominal [10, 20, 30]; B: nominal [5, 5, 5]; sumw2 = sumw.
# Summed shifts: jes up [3, -1, 3], jes down [-1, 2, 1] (B has no jesDown);
# toppt (one-sided, A only) [1, 0, 0]; scale envelope {mur1: [1, -2, 0], mur2: [-1, 1, 1]};
# pdf quadrature {pdf1: [1, 0, 0], pdf2: [0, -2, 0]}.
const EDGES = [0.0, 1.0, 2.0, 3.0]

h(w) = BinnedHist(EDGES, w, abs.(w))

function fixture_templates()
    entries = Dict(
        ("A", "nominal") => (EDGES, [10.0, 20.0, 30.0], [10.0, 20.0, 30.0]),
        ("A", "jesUp") => h([12.0, 19.0, 33.0]),
        ("A", "jesDown") => h([9.0, 22.0, 31.0]),
        ("A", "topptUp") => h([11.0, 20.0, 30.0]),
        ("A", "mur1") => h([11.0, 18.0, 30.0]),
        ("A", "mur2") => h([9.0, 21.0, 31.0]),
        ("A", "pdf1") => h([11.0, 20.0, 30.0]),
        ("A", "pdf2") => h([10.0, 18.0, 30.0]),
        ("B", "nominal") => (edges=EDGES, sumw=[5.0, 5.0, 5.0], sumw2=[5.0, 5.0, 5.0]),
        ("B", "jesUp") => Hist1D(EDGES, [6.0, 5.0, 5.0], [6.0, 5.0, 5.0]),
        ("D", "nominal") => (EDGES, [16.0, 24.0, 40.0], [16.0, 24.0, 40.0]))
    return collect_templates(entries)
end

fixture_config() = StackConfig([SampleGroup("Bkg B", "#1F77B4", ["B"]), SampleGroup("t#bar{t}", "#C5001A", ["A"])], ["D"])
