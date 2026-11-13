# Correctness / call-count / alias / error test for src/IO/stream_plan_branch_lookup.jl (rev2 final).
# NOT a timing benchmark.
# COVERAGE LABEL: FAKE. This test includes the ACTUAL candidate helper file into a stdlib-only
# module and checks it against a VERBATIM REPLICA (on fakes) of the UnROOT 0.11.11 public lookup
# (root.jl:169-182 ROOTFile getindex with get!/lock and slash split; root.jl:241-253 TTree first-match
# linear search returning missing). The full Cascade module and real UnROOT/ROOT files are NOT loaded,
# because no local environment can load UnROOT without resolve/install.
# Call-site lines of the candidate StreamWindowReader.jl/stream_selection.jl are checked textually
# and the candidate files are parsed.
module StreamPlanBranchLookupTest
using Test
const ROOT = abspath(get(ARGS, 1, joinpath(@__DIR__, "..", "..")))
include(joinpath(ROOT, "src", "IO", "stream_plan_branch_lookup.jl"))

const NAMEREADS = Ref(0)
struct FakeBranch; fName::Any; tag::Int; end
Base.getproperty(b::FakeBranch, s::Symbol) = (s === :fName && (NAMEREADS[] += 1); getfield(b, s))
struct FakeOther; fName::Any; end
struct NestedHit; parent::Int; rest::String; end
Base.getindex(b::FakeBranch, s::AbstractString) = NestedHit(getfield(b, :tag), String(s))
struct FakeArr{V}; elements::V; end
struct FakeTree{V}; fBranches::FakeArr{V}; end
FakeTree(els) = FakeTree(FakeArr(els))
struct OddArr; elements::Vector{Any}; end           # container without the support predicate
struct FakeTreeOdd; fBranches::OddArr; end
struct FakeTreeNoField; other::Int; end

# Cache wrapper that records writes made without the file lock held by this task.
struct LockCheckDict <: AbstractDict{Any,Any}
    d::Dict{Any,Any}; lock::ReentrantLock; unlocked::Base.RefValue{Int}
end
Base.get!(f::Base.Callable, x::LockCheckDict, k) =
    (islocked(x.lock) && x.lock.locked_by === current_task() || (x.unlocked[] += 1); get!(f, x.d, k))
Base.haskey(x::LockCheckDict, k) = haskey(x.d, k)
Base.get(x::LockCheckDict, k, default) = get(x.d, k, default)   # testfix: 3-arg get used by the helper's cached-tree read
Base.getindex(x::LockCheckDict, k) = x.d[k]
Base.setindex!(x::LockCheckDict, v, k) = (x.d[k] = v; x)
Base.length(x::LockCheckDict) = length(x.d)
Base.iterate(x::LockCheckDict, s...) = iterate(x.d, s...)

struct FakeFile
    directory::Dict{String,Any}; cache::LockCheckDict; lock::ReentrantLock; publics::Vector{String}
end
function FakeFile(dir)
    l = ReentrantLock()
    FakeFile(dir, LockCheckDict(Dict{Any,Any}(), l, Ref(0)), l, String[])
end
const GATE = Ref(true)                    # version/layout gate seam (production: IO.jl)
stream_plan_file_supported(::FakeFile) = GATE[]
stream_plan_tree_supported(::FakeTree) = true
stream_plan_tree_supported(::FakeTreeNoField) = true
stream_plan_tree_supported(::FakeTreeOdd) = true
stream_plan_container_supported(::FakeArr) = true
stream_plan_branch_supported(::FakeBranch) = true

# ---- verbatim replica of UnROOT 0.11.11 public lookup (on fakes) ----
function Base.getindex(f::FakeFile, s::AbstractString)
    push!(f.publics, String(s))
    Base.@lock f.lock begin
        get!(f.cache, s) do
            _getindex(f, s)
        end
    end
end
function _getindex(f::FakeFile, s)
    if '/' in s
        paths = split(s, '/')
        return f[first(paths)][join(paths[2:end], "/")]
    end
    haskey(f.directory, s) || throw(KeyError(s))
    return f.directory[s]
end
function Base.getindex(t::FakeTree, s::AbstractString)
    if '/' in s
        paths = split(s, '/')
        return t[first(paths)][join(paths[2:end], "/")]
    end
    for branch in t.fBranches.elements
        if branch.fName == s
            return branch
        end
    end
    missing
end

# Planner-loop replicas (StreamWindowReader.jl lookup + missing error + an early return).
function loop_public(f, tree, names; stop_at = nothing)
    out = Any[]
    for name in names
        b = f[string(tree, "/", name)]
        ismissing(b) && error("missing stream branch: $name")
        push!(out, b); name == stop_at && return out, "unsupported_branch"
    end
    return out, ""
end
function loop_indexed(f, tree, names; stop_at = nothing)
    lookup = stream_plan_branch_index(f, tree, names)
    out = Any[]
    for name in names
        b = lookup === nothing ? f[string(tree, "/", name)] : stream_plan_branch(f, tree, name, lookup)
        ismissing(b) && error("missing stream branch: $name")
        push!(out, b); name == stop_at && return out, "unsupported_branch", lookup
    end
    return out, "", lookup
end
cachestate(f) = sort!([(k, v) for (k, v) in f.cache.d]; by = first)
same_cache(a, b) = (ka = cachestate(a); kb = cachestate(b);
    length(ka) == length(kb) && all(x[1] == y[1] && x[2] === y[2] for (x, y) in zip(ka, kb)))
twofiles(dir) = (FakeFile(copy(dir)), FakeFile(copy(dir)))   # SAME tree/branch objects in both
# As in the planner: nevents() has already put the tree in the file cache before the branch loop.
function precached(f, tree = "Events")
    haskey(f.directory, tree) && f[tree]
    empty!(f.publics); return f
end
prepared(dir) = map(precached, twofiles(dir))
function capture(g)
    try
        g(); return nothing
    catch e
        return e
    end
end

const NB = 2000
const ELS = Any[FakeBranch("b$i", i) for i in 1:NB]
ELS[1500] = FakeBranch("dup", 1500); ELS[1700] = FakeBranch("dup", 1700)
const TREE = FakeTree(ELS)
const DIR = Dict{String,Any}("Events" => TREE)
const NAMES = vcat(["b$i" for i in 5:33:NB if i != 1500 && i != 1700], ["dup", "nMuon_absent_never"][1:1])
report = Dict{String,Any}()

@testset "stream_plan_branch_lookup (FAKE coverage)" begin
    @testset "identical objects, cache, order; fewer element scans and public lookups" begin
        fp, fi = prepared(DIR)
        NAMEREADS[] = 0; outp, rp = loop_public(fp, "Events", NAMES); reads_public = NAMEREADS[]
        NAMEREADS[] = 0; outi, ri, lk = loop_indexed(fi, "Events", NAMES); reads_indexed = NAMEREADS[]
        @test rp == ri == ""
        @test length(outp) == length(outi) && all(outp .=== outi)
        @test all(outi[k] === ELS[parse(Int, NAMES[k][2:end])] for k in eachindex(NAMES) if NAMES[k] != "dup")
        @test outi[end] === ELS[1500]                       # first match, not 1700
        @test same_cache(fp, fi)
        @test lk.elements === TREE.fBranches.elements       # borrowed alias, no copy
        @test fp.publics == vcat([["Events/" * n, "Events"] for n in NAMES]...)
        @test isempty(fi.publics)                           # index uses the cached tree; no public lookup
        @test fp.cache.unlocked[] == 0 && fi.cache.unlocked[] == 0
        @test !islocked(fi.lock)
        maxpos = maximum(n == "dup" ? 1500 : parse(Int, n[2:end]) for n in NAMES)
        @test reads_indexed == maxpos                       # single scan, stops at last needed
        @test reads_indexed < reads_public
        # Later public lookups (e.g. LazyBranch(file, "Events/name") in the planner) hit the same objects.
        empty!(fi.publics); NAMEREADS[] = 0
        @test all(fi[string("Events/", n)] === outi[k] for (k, n) in enumerate(NAMES)) && NAMEREADS[] == 0
        report["fname_reads_public"] = reads_public; report["fname_reads_indexed"] = reads_indexed
        report["public_lookups_public"] = length(fp.publics) ; report["names"] = length(NAMES)
    end
    @testset "missing branch: same cached missing and same error" begin
        fp, fi = prepared(DIR); names = ["b10", "absent", "b20"]
        ep = capture(() -> loop_public(fp, "Events", names))
        NAMEREADS[] = 0
        ei = capture(() -> loop_indexed(fi, "Events", names))
        @test ep isa ErrorException && ei isa ErrorException && ep.msg == ei.msg == "missing stream branch: absent"
        @test same_cache(fp, fi) && fi.cache.d["Events/absent"] === missing
        @test !haskey(fi.cache.d, "Events/b20")             # nothing cached past the failure
        @test NAMEREADS[] == NB                             # absent name: one full scan
    end
    @testset "early planner return leaves identical cache" begin
        fp, fi = prepared(DIR); names = ["b7", "b900", "b3", "b1999"]
        op, rp = loop_public(fp, "Events", names; stop_at = "b900")
        oi, ri, _ = loop_indexed(fi, "Events", names; stop_at = "b900")
        @test rp == ri == "unsupported_branch" && all(op .=== oi) && same_cache(fp, fi)
        @test !haskey(fi.cache.d, "Events/b3") && !haskey(fi.cache.d, "Events/b1999")
    end
    @testset "prepopulated cache entry wins" begin
        fp, fi = prepared(DIR); sentinel = FakeBranch("b5", -5)
        fp.cache.d["Events/b5"] = sentinel; fi.cache.d["Events/b5"] = sentinel
        op, _ = loop_public(fp, "Events", ["b5", "b6"]); oi, _, _ = loop_indexed(fi, "Events", ["b5", "b6"])
        @test op[1] === oi[1] === sentinel && op[2] === oi[2] === ELS[6] && same_cache(fp, fi)
    end
    @testset "nested path name uses the unchanged public path" begin
        fp, fi = prepared(DIR); names = ["b4", "b8/sub"]
        op, _ = loop_public(fp, "Events", names); oi, _, lk = loop_indexed(fi, "Events", names)
        @test lk !== nothing && !haskey(lk.positions, "b8/sub")
        @test oi[2] == op[2] == NestedHit(8, "sub") && same_cache(fp, fi)
        @test "Events/b8/sub" in fi.publics
    end
    @testset "unsupported shapes return nothing (caller keeps public path)" begin
        @test stream_plan_branch_index(Dict("Events" => TREE), "Events", ["b1"]) === nothing  # unsupported file
        f = FakeFile(Dict{String,Any}("dir/Events" => TREE)); f.cache.d["dir/Events"] = TREE
        @test stream_plan_branch_index(f, "dir/Events", ["b1"]) === nothing && isempty(f.publics)
        f = FakeFile(Dict{String,Any}("Events" => TREE))                       # tree not cached yet
        @test stream_plan_branch_index(f, "Events", ["b1"]) === nothing && isempty(f.publics) && isempty(f.cache.d)
        for tr in ("TNamed title", FakeTree(Any[]), FakeTreeOdd(OddArr(Any[FakeBranch("b1", 1)])),
                   FakeTreeNoField(1), FakeTree((FakeBranch("b1", 1),)))
            f = precached(FakeFile(Dict{String,Any}("Events" => tr)))
            @test stream_plan_branch_index(f, "Events", ["b1"]) === nothing    # no throw, no lookup
            @test isempty(f.publics)
        end
        els = Any[FakeBranch("b1", 1), FakeOther("b2"), FakeBranch("b3", 3)]
        f = precached(FakeFile(Dict{String,Any}("Events" => FakeTree(els))))
        @test stream_plan_branch_index(f, "Events", ["b3"]) === nothing      # unsupported element before match
        @test stream_plan_branch_index(f, "Events", ["b1"]) !== nothing      # stops before it, same as public
        f = precached(FakeFile(Dict{String,Any}("Events" => FakeTree(Any[FakeBranch(:b1, 1)]))))
        @test stream_plan_branch_index(f, "Events", ["b1"]) === nothing      # non-String fName
        # non-AbstractString query names: no early throw, whole index falls back
        f = precached(FakeFile(copy(DIR)))
        @test stream_plan_branch_index(f, "Events", Any["b1", 7]) === nothing && isempty(f.publics)
        @test stream_plan_branch_index(f, "Events", Any[:b1]) === nothing
        fp, fi = prepared(DIR)
        ep = capture(() -> loop_public(fp, "Events", Any["b1", 7])); ei = capture(() -> loop_indexed(fi, "Events", Any["b1", 7]))
        @test ep isa ErrorException && ei isa ErrorException && ep.msg == ei.msg == "missing stream branch: 7"
        @test same_cache(fp, fi) && fi.cache.d["Events/7"] === missing
        lk = stream_plan_branch_index(fi, "Events", ["b2"]); empty!(fi.publics)
        @test stream_plan_branch(fi, "Events", 7, lk) === missing && fi.publics == ["Events/7"]  # public path, no String(7)
        # fallback loops still equal public results
        els2 = Any[FakeBranch("b1", 1), missing, FakeBranch("b3", 3)]
        fp, fi = prepared(Dict{String,Any}("Events" => FakeTree(els2)))
        op, _ = loop_public(fp, "Events", ["b1"]); oi, _, lk = loop_indexed(fi, "Events", ["b1"])
        @test op[1] === oi[1] && same_cache(fp, fi)
        ep = capture(() -> loop_public(fp, "Events", ["b3"])); ei = capture(() -> loop_indexed(fi, "Events", ["b3"]))
        @test typeof(ep) == typeof(ei) && same_cache(fp, fi)                 # same error from public path
    end
    @testset "P2 empty tree name, gate false, tree without fBranches + prepopulated keys" begin
        f = precached(FakeFile(copy(DIR)))
        @test stream_plan_branch_index(f, "", ["b1"]) === nothing && isempty(f.publics)
        GATE[] = false
        try
            @test stream_plan_branch_index(f, "Events", ["b1"]) === nothing && isempty(f.publics)
        finally
            GATE[] = true
        end
        d = Dict{String,Any}("Events" => FakeTreeNoField(1)); fp, fi = prepared(d)
        x = FakeBranch("b1", 1); y = FakeBranch("b2", 2)
        for f in (fp, fi); f.cache.d["Events/b1"] = x; f.cache.d["Events/b2"] = y; empty!(f.publics); end
        op, rp = loop_public(fp, "Events", ["b1", "b2"]); oi, ri, lk = loop_indexed(fi, "Events", ["b1", "b2"])
        @test lk === nothing && rp == ri == "" && op[1] === oi[1] === x && op[2] === oi[2] === y
        @test fp.publics == fi.publics == ["Events/b1", "Events/b2"] && same_cache(fp, fi)
    end
    @testset "prepopulated full-path cache, tree absent: no throw, same results" begin
        fp, fi = twofiles(Dict{String,Any}())
        x = FakeBranch("b1", 1)
        for f in (fp, fi); f.cache.d["Events/b1"] = x; end
        op, rp = loop_public(fp, "Events", ["b1"]); oi, ri, lk = loop_indexed(fi, "Events", ["b1"])
        @test lk === nothing && rp == ri == "" && op[1] === oi[1] === x && fp.publics == fi.publics == ["Events/b1"]
    end
    @testset "missing tree raises the same KeyError" begin
        fp, fi = twofiles(Dict{String,Any}())
        ep = capture(() -> loop_public(fp, "Events", ["b1"])); ei = capture(() -> loop_indexed(fi, "Events", ["b1"]))
        @test ep isa KeyError && ei isa KeyError && ep.key == ei.key == "Events"
    end
    @testset "SubString names and no retained state" begin
        fp, fi = prepared(DIR); names = [SubString("xb12", 2), SubString("xb13", 2)]
        op, _ = loop_public(fp, "Events", names); oi, _, lk = loop_indexed(fi, "Events", names)
        @test all(op .=== oi) && same_cache(fp, fi)
        @test fieldnames(StreamPlanBranchIndex) == (:elements, :positions)
        @test sort!(collect(keys(lk.positions))) == ["b12", "b13"]
    end
    @testset "candidate call sites (text) and parse" begin
        sw = read(joinpath(ROOT, "src", "IO", "StreamWindowReader.jl"), String)
        ss = read(joinpath(ROOT, "src", "Pipeline", "stream_selection.jl"), String)
        io = read(joinpath(ROOT, "src", "IO", "IO.jl"), String)
        @test occursin("options; counter_names = post,\n        indexed_branch_lookup = false)", sw)
        @test occursin("lookup = indexed_branch_lookup === true ? stream_plan_branch_index(src.file, src.tree, names) : nothing", sw)
        @test occursin("b = lookup === nothing ? src.file[string(src.tree,\"/\",name)] : stream_plan_branch(src.file, src.tree, name, lookup)", sw)
        @test count("stream_plan_branch", ss) == 0 && count("indexed_branch_lookup=true", ss) == 1
        @test occursin("counter_names=unique(vcat(pre, post)), indexed_branch_lookup=true)", ss)
        @test count("plan_stream_windows(", ss) == 3              # other two callers keep the default
        @test occursin("    end\n    lookup = nothing   # drop temporary plan-local lookup scratch (unreachable) before metadata sizing\n", sw)
        @test findfirst("lookup = nothing   # drop", sw).start < findfirst("descriptor_bytes=Base.summarysize", sw).start
        # B1: StreamWindowReader.jl defines no UnROOT-typed support methods; IO.jl does, before including it.
        @test !occursin("stream_plan_file_supported", sw) && !occursin("stream_plan_tree_supported", sw) &&
              !occursin("stream_plan_container_supported", sw) && !occursin("stream_plan_branch_supported", sw)
        gate = "stream_plan_unroot_layout_supported() = Base.pkgversion(UnROOT) == v\"0.11.11\" &&\n    hasfield(UnROOT.ROOTFile, :cache) && fieldtype(UnROOT.ROOTFile, :cache) === Dict{Any,Any} &&\n    hasfield(UnROOT.ROOTFile, :lock) && fieldtype(UnROOT.ROOTFile, :lock) === ReentrantLock\n"
        @test occursin(gate, io)
        for m in ("stream_plan_file_supported(::UnROOT.ROOTFile) = stream_plan_unroot_layout_supported()",
                  "stream_plan_tree_supported(::UnROOT.TTree) = true", "stream_plan_container_supported(::UnROOT.TObjArray) = true",
                  "stream_plan_branch_supported(::Union{UnROOT.TBranch,UnROOT.TBranchElement}) = true")
            i = findfirst(m, io); @test i !== nothing
            @test findfirst("include(\"stream_plan_branch_lookup.jl\")", io).start < i.start < findfirst("include(\"StreamWindowReader.jl\")", io).start
        end
        hl = read(joinpath(ROOT, "src", "IO", "stream_plan_branch_lookup.jl"), String)
        @test occursin("    isempty(tree) && return nothing\n    '/' in tree && return nothing\n", hl) && !occursin("UnROOT.", hl)
        @test occursin("StreamWindowReader(src,branches,String.(pre),String.(post),counters,windows,charges,options,diag,Set{Tuple{String,Int}}())", sw)
        for (nm, txt) in (("StreamWindowReader.jl", sw), ("stream_selection.jl", ss), ("IO.jl", io),
                          ("stream_plan_branch_lookup.jl", read(joinpath(ROOT, "src", "IO", "stream_plan_branch_lookup.jl"), String)))
            ex = Meta.parseall(txt; filename = nm)
            bad = Any[]
            walk(x) = (x isa Expr && (x.head in (:error, :incomplete) && push!(bad, x); foreach(walk, x.args)); nothing)
            walk(ex)
            @test isempty(bad)
        end
    end
end
println("REPORT ", report)
end
