"""Bounded, source-free primitive decode/assembly coverage for package images."""
function _precompile_decode_workload()
    cases = 0
    for E in (Bool, Int8, UInt8, Int16, UInt16, Int32, UInt32, Int64, UInt64, Float32, Float64)
        values = E[zero(E), one(E)]
        content = collect(reinterpret(UInt8, hton.(values)))
        for jagged in (false, true), compressed in (false, true)
            T = jagged ? Vector{E} : E
            J = jagged ? UnROOT.Nooffsetjagg : UnROOT.Nojagg
            n = jagged ? 3 : 2
            raw = jagged ? vcat(content, zeros(UInt8,4),
                collect(reinterpret(UInt8, hton.(Int32[32,32+sizeof(E),32+sizeof(E)]))), zeros(UInt8,4)) : copy(content)
            bytes = if compressed
                stream = transcode(UnROOT.XzCompressor, raw)
                c = length(stream); d = length(raw)
                vcat(UInt8[0x58,0x5a,0,c&255,(c>>8)&255,(c>>16)&255,d&255,(d>>8)&255,(d>>16)&255],stream)
            else
                copy(raw)
            end
            blocks = compressed ? validate_decode_blocks(bytes,length(raw)) : ()
            compressed && @assert validate_decode_blocks(view(bytes,1:length(bytes)),length(raw)) == blocks
            key = UnROOT.TBasketKey(fNbytes=length(bytes)+32,fVersion=1,fObjlen=length(raw),
                fDatime=0,fKeylen=32,fCycle=1,fSeekKey=0,fSeekPdir=0,fClassName="TBasket",
                fName="precompile",fTitle="",fBufferSize=0,fNevBufSize=0,fNevBuf=n,fLast=length(content)+32)
            basket = decode_prepared_basket((key=key,bytes=bytes,blocks=blocks,T=T,J=J,entries=n))
            for masked in (false,true)
                offsets = jagged && masked ? [0,1,1,2] : nothing
                plan = (name="precompile",T=T,J=J,E=E,jagged=jagged,masked=masked,offsets=offsets,n=n)
                state = (values=jagged && !masked ? E[] : zeros(E,2),
                    offsets=jagged ? (masked ? copy(offsets) : zeros(Int,n+1)) : Int[])
                descriptor = (branch=1,basket=1,lo=1,hi=n,skip=false,charge=0,pos=0,
                    key=key,blocks=blocks,compressed=length(bytes))
                assemble_decoded_basket!(plan,state,descriptor,basket)
                @assert state.values == values
                jagged && @assert state.offsets == [0,1,1,2]
                skipped = merge(descriptor,(skip=true,key=nothing,blocks=(),compressed=0))
                assemble_decoded_basket!(plan,state,skipped,nothing)
                !jagged && @assert all(iszero,state.values)
            end
            cases += 1
        end
    end
    return cases
end

# No runtime warmup, source opens, tasks, or external input at package load.
if ccall(:jl_generating_output, Cint, ()) == 1
    _precompile_decode_workload()
    # The serial reader also calls this standalone Bool specialization; the typed
    # interpretation barrier can inline it without retaining its own code entry.
    precompile(UnROOT.interped_data, (Vector{UInt8},Vector{Int32},Type{Bool},Type{UnROOT.Nojagg}))
end
