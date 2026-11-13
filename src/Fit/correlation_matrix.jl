"""
    correlation_matrix(result::FitResult) -> Matrix

Correlation matrix of the fitted parameters (zero rows/columns for fixed ones).
"""
function correlation_matrix(result::FitResult)
    s = result.uncertainties
    n = length(s)
    C = zeros(n, n)
    for i in 1:n, j in 1:n
        (s[i] > 0 && s[j] > 0) && (C[i, j] = result.covariance[i, j] / (s[i] * s[j]))
    end
    return C
end
