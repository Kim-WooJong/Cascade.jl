# Opt-in skim-only metadata prefix. Never used by select/column reads.
# Julia code below follows UnROOT0.11.11 TTree's FOUR versioned base-class reads,
# then its first Int64 field. No invented offsets, branch parsing, or parser replacement.
const SKIM_ENTRYCOUNT_SOURCE_PINS = (
    ("UnROOT.jl", "6817bf6b6564c2cb42fd6cbdc93328545aab4af87d285d55c421f99571c462c3"),
    ("constants.jl", "525690baedf2b7a4131e140e35bb24ff6cb5251c032ed1f6b69e7d586ec4d358"),
    ("io.jl", "48a8183796f8fe158563e5fb2a18508a94b2fec2bb6c3dd64375413abcf9f54c"),
    ("types.jl", "f6893cae8dbf7155f34ba4ff72f78dd90227f3d93b984666d21631761754f101"),
    ("bootstrap.jl", "5fc968ff9b33d3ae2ab431f69b3c615cc0f44231b1ba6c02c23611d21c6afd2f"),
    ("streamers.jl", "7f3e78237019c7fa8f070d3286368cc97acbbf98c08584494b9d917c740894cf"),
    ("root.jl", "1ad30a0df179354296d118881b72d158c7a8f1ee27882ffa8a8638a5bb813cc2"),
    ("streamsource.jl", "6b05030ed43d8d1b79578581eaeb66569f611122d11bea27c0d698216741969f"),
    ("utils.jl", "e99373f26f51625cccd11affd2543c770162ab7bfaebf536118697d47931c69f"),
)
function skim_entrycount_contract(; version=Base.pkgversion(UnROOT),directory=dirname(pathof(UnROOT)))
    version==v"0.11.11" || return false
    !isempty(SKIM_ENTRYCOUNT_SOURCE_PINS) || return false
    for (name,expected) in SKIM_ENTRYCOUNT_SOURCE_PINS
        p=joinpath(directory,name)
        isfile(p) && bytes2hex(sha256(read(p)))==expected || return false
    end
    return true
end
"""Return nothing BEFORE admission for an unsupported TTree prefix format.
Once supported version20+bytecount framing is admitted, malformed prefix throws.
The branch/index/friend tail is NOT parsed/validated here; select's ordinary full
UnROOT parser remains mandatory and unchanged before final publication.
"""
function skim_ttree_prefix_entries(io; declared_bytes::Int)
    0<=declared_bytes || error("negative TTree metadata length")
    position(io)==0 && bytesavailable(io)==declared_bytes || error("TTree datastream length mismatch")
    declared_bytes>=6 || error("truncated TTree preamble")
    preamble=UnROOT.Preamble(io,Missing)
    # Explicit supported schema, not UnROOT's broad 'everything except v5' assumption.
    preamble.version==20 || return nothing
    ismissing(preamble.cnt) && return nothing
    preamble.start==0 && 6<=preamble.cnt<=declared_bytes || error("invalid TTree object bytecount")
    preamble.cnt==declared_bytes || error("TTree object bytecount differs from declared metadata")
    fields=Dict{Symbol,Any}()
    UnROOT.stream!(io,fields,UnROOT.TNamed)
    UnROOT.stream!(io,fields,UnROOT.TAttLine)
    UnROOT.stream!(io,fields,UnROOT.TAttFill)
    UnROOT.stream!(io,fields,UnROOT.TAttMarker)
    position(io)+8<=preamble.start+preamble.cnt || error("truncated TTree fEntries prefix")
    n=UnROOT.readtype(io,Int64)
    0<=n<=typemax(Int) || error("invalid TTree event count")
    # Do NOT seek to the end and pretend endcheck validated the unparsed branch tail.
    return Int(n)
end
"""Skim only: no source/file/tree cache insertion; Runs normalization is a separate unchanged call."""
function skim_nanoaod_entrycount(src::NanoAODSource; max_metadata_bytes::Int)
    max_metadata_bytes>0 || throw(ArgumentError("positive skim metadata bound required"))
    # Eligibility and source/version checks happen before prefix admission.
    ('/' in src.tree || !(src.file.fobj isa UnROOT.MmapStream)) && return nothing
    skim_entrycount_contract() || return nothing
    f=src.file
    return Base.@lock f.lock begin
        i=findfirst(k->k.fName==src.tree,f.directory.keys)
        i===nothing && return nothing # original nevents raises its usual missing-key error
        key=f.directory.keys[i]
        key.fClassName=="TTree" || return nothing
        key.fVersion>0 || error("malformed skim TTree key version")
        key.fVersion in (4,1004) || return nothing # supported existing TKey32/64 schema only
        # Same source-mapping boundary contract, bounded decompression BEFORE datastream.
        0<key.fKeylen<=key.fNbytes && 0<=key.fObjlen || error("malformed skim TTree key lengths")
        0<=key.fSeekKey && Int128(key.fSeekKey)+key.fNbytes<=length(f.fobj.mmap_ary) || error("skim TTree key outside source")
        max(key.fNbytes-key.fKeylen,key.fObjlen)<=max_metadata_bytes || error("skim TTree metadata exceeds configured bound")
        io=UnROOT.datastream(f.fobj,key)
        try
            skim_ttree_prefix_entries(io;declared_bytes=Int(key.fObjlen))
        finally
            close(io)
        end
    end
end
