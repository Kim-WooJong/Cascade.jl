# Serial, caller-owned storage only. No codec/native resource survives a branch read.
mutable struct _NanoAODScratch
    raw::Vector{UInt8}
    audited::Union{Nothing,Bool}
end
_NanoAODScratch() = _NanoAODScratch(UInt8[], nothing)

# The fixed raw window and native decoder limit are independent bounds.
_nanoaod_scratch_limit() = 8 * 1024^2
# Admit a 64 MiB LZMA2 dictionary plus decoder bookkeeping, still bounded.
_nanoaod_decoder_limit() = 66 * 1024^2

function _reusable_decode_contract()
    isempty(decode_dependency_contract().reason) || return false
    xz = UnROOT.CodecXz
    ts = xz.TranscodingStreams
    pkgversion(xz) == v"0.7.4" && pkgversion(ts) == v"0.11.3" || return false
    # This is an additional gate, not an extension of the detached whitelist.
    for (mod, files) in ((xz, (
            ("CodecXz.jl", "a0949943de650c1e4353fd72c8b2606db16fcb167d910b6fc3aeb8f9c9afbd83"),
            ("decompression.jl", "86d16993077ab9bcd92cbc87d7c41ae23140fc042203571e15e093f47d26c3fc"),
            ("liblzma.jl", "07b5474a314a06f84d161e73e57aa3412e573bf5a6da89d3f4c107bc135a1a23"))),
            (ts, (
            ("TranscodingStreams.jl", "37fa066ff998a0f6d83415e4664b22d6d42fe6b15d8266fbb16ea42b1ce2a0c4"),
            ("memory.jl", "1ba6489450ad17f36b9cf32fc8410f7adb8a2471f4282139743e28c31a6c819a"),
            ("error.jl", "f7706acdebad913a4c60801fdf8925c78a365e30bd3983ae116a5dc3f4c630b1"),
            ("codec.jl", "ef24af8a009bef79cb75745a30ad2d963e2ed420fe81dbc19ae71b0a33186ecb"))))
        for (name, expected) in files
            path = joinpath(dirname(pathof(mod)), name)
            isfile(path) && bytes2hex(sha256(read(path))) == expected || return false
        end
    end
    return true
end

function _reusable_branch(lb, scratch, starts, ::Type{E}, jagged) where {E}
    scratch === nothing && return nothing
    starts === nothing && return nothing
    lb.f.fobj isa UnROOT.MmapStream || return nothing
    lb.b isa UnROOT.TBranch || return nothing
    length(lb.b.fLeaves.elements) == 1 || return nothing
    E in (Bool, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64) || return nothing
    scratch.audited === nothing && (scratch.audited = _reusable_decode_contract())
    scratch.audited || return nothing
    T, J = UnROOT.auto_T_JaggT(lb.f, lb.b; customstructs = lb.f.customstructs)
    decode_interpretation_supported(lb.b, T, J) || return nothing
    (jagged ? (T <: AbstractVector && eltype(T) === E) : T === E) || return nothing
    return (scratch = scratch, codec = Ref{Any}(nothing))
end

function _close_reusable_branch(state)
    state === nothing && return nothing
    codec = state.codec[]
    codec === nothing || UnROOT.CodecXz.TranscodingStreams.finalize(codec)
    state.codec[] = nothing
    return nothing
end

# Fixed output windows, unlike growing transcode output. :end is required even
# when the declared output is full; zero output space still permits CRC/footer
# consumption. A stalled/error/overlong/truncated stream is never retried.
function _decode_xz_window!(raw, mapped, q, c, base, d, state)
    ts = UnROOT.CodecXz.TranscodingStreams
    codec = state.codec[]
    if codec === nothing
        codec = UnROOT.XzDecompressor(; memlimit = _nanoaod_decoder_limit())
        state.codec[] = codec
        ts.initialize(codec)
    end
    err = ts.Error()
    ts.startproc(codec, :write, err) === :ok || throw(err[])
    consumed = 0; supplied = 0
    while true
        ni, no, status = GC.@preserve raw mapped begin
            ts.process(codec, ts.Memory(pointer(mapped, q + consumed), UInt(c - consumed)),
                ts.Memory(pointer(raw, base + supplied + 1), UInt(d - supplied)), err)
        end
        0 <= ni <= c-consumed && 0 <= no <= d-supplied || error("XZ decoder exceeded fixed window")
        consumed += ni; supplied += no
        status === :error && throw(err[])
        if status === :end
            consumed == c && supplied == d || error("XZ stream length mismatch")
            return nothing
        end
        status === :ok || error("invalid XZ decoder status")
        ni > 0 || no > 0 || error("truncated or oversized XZ stream")
    end
end
