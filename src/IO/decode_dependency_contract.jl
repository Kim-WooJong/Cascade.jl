"""Invocation-local source audit, never a global trust cache or a semver-only pin."""
function decode_dependency_contract(; version = pkgversion(UnROOT), directory = dirname(pathof(UnROOT)))
    expected = Dict(
        "UnROOT.jl" => "6817bf6b6564c2cb42fd6cbdc93328545aab4af87d285d55c421f99571c462c3",
        "io.jl" => "48a8183796f8fe158563e5fb2a18508a94b2fec2bb6c3dd64375413abcf9f54c",
        "bootstrap.jl" => "5fc968ff9b33d3ae2ab431f69b3c615cc0f44231b1ba6c02c23611d21c6afd2f",
        "root.jl" => "1ad30a0df179354296d118881b72d158c7a8f1ee27882ffa8a8638a5bb813cc2",
        "iteration.jl" => "b2b8cfeca2d8480cc7e2909fdd387eef8a41b5f81a82a05a3ce70f5dcf12effb",
        "streamsource.jl" => "6b05030ed43d8d1b79578581eaeb66569f611122d11bea27c0d698216741969f",
        "types.jl" => "f6893cae8dbf7155f34ba4ff72f78dd90227f3d93b984666d21631761754f101",
        "utils.jl" => "e99373f26f51625cccd11affd2543c770162ab7bfaebf536118697d47931c69f",
        "custom.jl" => "826c431e308835848dd879dd4c7149bc9a1d407a3bf7157d614e7d41c7c9fbd1")
    actual = Dict{String,String}()
    reason = version == v"0.11.11" ? "" : "unsupported_unroot_version"
    for name in sort!(collect(keys(expected)))
        path = joinpath(directory, name)
        actual[name] = isfile(path) ? bytes2hex(sha256(read(path))) : "missing"
        actual[name] == expected[name] || (reason = "unroot_source_contract")
    end
    return (reason = reason, record = Dict("version" => string(version), "sha256" => actual,
        "contract" => "UnROOT-0.11.11-detached-xz-regular-v2"))
end
