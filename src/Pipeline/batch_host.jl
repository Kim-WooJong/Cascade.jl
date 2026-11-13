"""Return the local host identity used to constrain safe POSIX claim recovery."""
function batch_host()
    return strip(read(`hostname`, String))
end
