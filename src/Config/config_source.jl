"""
    read_analysis_source(path; check_keys=true) -> (; raw, provenance)

Compose explicit top-level include lists depth-first, in declaration order, then
merge the declaring file. Tables merge; any repeated leaf (including an entire
array) is an error, even if equal. Profiles overlay only during resolve_config.
Include paths are relative to their declaring file; analysis assets retain the
entry directory. No loader metadata enters raw or scientific section hashes.
"""
function read_analysis_source(path::AbstractString; check_keys::Bool = true)
    entry = abspath(path)
    dependencies = Dict{String,Any}[]
    active = String[]
    seen = Set{Tuple{UInt,UInt}}()
    owners = Dict{Tuple,String}()
    raw = Dict{String,Any}()
    function merge_unique!(dest, src, keys, file)
        for (k, value) in src
            key = (keys..., k)
            if haskey(dest, k)
                if dest[k] isa AbstractDict && value isa AbstractDict
                    merge_unique!(dest[k], value, key, file)
                else
                    previous = get(owners, key, "another included table")
                    throw(ArgumentError("configuration key $(join(key, '.')) conflicts: $previous and $file (arrays cannot be split or overridden by include)"))
                end
            else
                dest[k] = deepcopy(value)
            end
            get!(owners, key, file)
            if value isa AbstractDict
                # Record every leaf's source even when the whole table is new.
                function record(t, prefix)
                    for (name, v) in t
                        q = (prefix..., name)
                        get!(owners, q, file)
                        v isa AbstractDict && record(v, q)
                    end
                end
                record(value, key)
            end
        end
    end
    function visit(file, depth)
        depth <= 64 || throw(ArgumentError("configuration include depth exceeds 64: $file"))
        isfile(file) || throw(ArgumentError("configuration include is not a regular file: $file"))
        identity = realpath(file)
        identity in active && throw(ArgumentError("configuration include cycle: $(join(vcat(active, identity), " -> "))"))
        st = stat(file)
        file_id = (UInt(st.device), UInt(st.inode))
        file_id in seen && throw(ArgumentError("configuration file included more than once: $file ($identity)"))
        push!(seen, file_id); push!(active, identity)
        bytes = read(file)
        digest = bytes2hex(sha256(bytes))
        d = try
            TOML.parse(String(copy(bytes)))
        catch e
            throw(ArgumentError("configuration $file: $(sprint(showerror, e))"))
        end
        includes = pop!(d, "include", String[])
        includes isa AbstractVector && all(x -> x isa AbstractString && !isempty(strip(x)) && !occursin('\0', x), includes) ||
            throw(ArgumentError("$file: include must be an array of nonempty literal file paths"))
        push!(dependencies, Dict("path" => normpath(abspath(file)), "realpath" => identity, "sha256" => digest))
        for child in includes
            visit(normpath(joinpath(dirname(file), child)), depth + 1)
        end
        merge_unique!(raw, d, (), file)
        pop!(active)
    end
    visit(entry, 1)
    if check_keys
        try
            validate_keys(raw)
        catch e
            # Schema and cross-field checks must see the complete configuration.
            # Preserve exact source attribution for merged tables and their leaves.
            message = sprint(showerror, e)
            matches = filter(collect(owners)) do (key, _)
                occursin(join(key, '.'), message) ||
                    (occursin("'$(last(key))'", message) && occursin(join(key[1:end-1], '.'), message))
            end
            sort!(matches; by=x -> -length(first(x)))
            files = isempty(matches) ? [d["path"] for d in dependencies] : unique(last.(matches))
            throw(ArgumentError("configuration $entry: $message; source files: $(join(files, ", "))"))
        end
    end
    provenance = _config_source_provenance(entry, dependencies)
    # Re-read every dependency, including its symlink target, after composition.
    # This catches ordinary concurrent edits without pretending to lock writers.
    verify_config_sources(provenance)
    return (; raw, provenance)
end

function _config_source_provenance(entry, dependencies)
    single = length(dependencies) == 1
    digest = if single
        dependencies[1]["sha256"] # Preserve historical byte SHA for one-file configs.
    else
        io = IOBuffer()
        print(io, "cascade-config-closure-v1\n")
        for dep in dependencies
            # Length framing makes filenames unambiguous. Relative paths permit relocation.
            p = relpath(dep["path"], dirname(entry))
            print(io, ncodeunits(p), ':', p, ':', dep["sha256"], '\n')
        end
        bytes2hex(sha256(take!(io)))
    end
    return Dict{String,Any}("sha256" => digest,
        "scope" => single ? "main analysis TOML only (single file); payloads, input files and environment excluded" :
            "cascade-config-closure-v1: ordered entry and transitive include paths and byte SHA256; payloads, input files and environment excluded",
        "dependencies" => dependencies)
end

"Verify captured TOML bytes/targets have not changed; never opens analysis data."
function verify_config_sources(provenance::AbstractDict)
    for dep in provenance["dependencies"]
        p = dep["path"]
        isfile(p) && realpath(p) == dep["realpath"] && bytes2hex(open(sha256, p)) == dep["sha256"] ||
            throw(ArgumentError("configuration source changed while in use: $p"))
    end
    return provenance
end

"Current full TOML closure identity; includes inactive profiles and comments."
config_provenance(path::AbstractString) = read_analysis_source(path).provenance

"Compare a captured closure with current includes/bytes before data work/publication."
function verify_config_provenance(path::AbstractString, expected::AbstractDict)
    current = config_provenance(path)
    current == expected || throw(ArgumentError("configuration dependency closure changed: $path"))
    return current
end

"Validate a batch config identity; legacy single-file manifests remain accepted."
function verify_config_manifest(path::AbstractString, manifest::AbstractDict)
    current = config_provenance(path)
    current["sha256"] == manifest["config_sha256"] || throw(ArgumentError("batch configuration changed: $path"))
    if haskey(manifest, "config_dependencies")
        current["dependencies"] == manifest["config_dependencies"] || throw(ArgumentError("batch configuration dependencies changed: $path"))
        current["scope"] == manifest["config_sha256_scope"] || throw(ArgumentError("batch configuration hash scope changed"))
    elseif length(current["dependencies"]) != 1
        throw(ArgumentError("legacy batch manifest does not cover included configuration files"))
    end
    return current
end
