# Source slices adapted from UnROOT.jl v0.11.11, Copyright (c) 2019 Tamas Gal.
# MIT permission notice and adaptation details: ../../THIRD_PARTY.md.
module FixtureUnROOT
const ntoh=Base.ntoh
struct Cursor
    io::IO
end
abstract type ROOTStreamedObject end
struct TObject <: ROOTStreamedObject end
parsefields!(io,fields,::Type{TObject})=skiptobj(io)
module Const
const kByteCountMask  = Int64(0x40000000)
const kIsReferenced   = UInt32(16)
end
@inline readtype(io, ::Type{T}) where T<:Union{Integer, AbstractFloat} = ntoh(read(io, T))
@inline readtype(io, ::Type{T}) where T<:Bool = read(io, T)
@inline readtype(io, v::Type{T}) where T<:AbstractVector{UInt8} = read(io, length(v))

# Non-C strings in .root are proceeded by 1 or more bytes signifying the length
# of the string that follows.
function readtype(io, ::Type{T}) where T<:AbstractString
    length = readtype(io, UInt8)

    if length == 255
        # first byte 0xff is useless now
        # https://github.com/scikit-hep/uproot3/blob/54f5151fb7c686c3a161fbe44b9f299e482f346b/uproot3/source/cursor.py#L91
        length = readtype(io, UInt32)
    end

    T(read(io, length))
end

struct Preamble
    start::Int64
    cnt::Union{UInt32, Missing}
    version::UInt16
    type::Type
end

"""
Reads the preamble of an object.

The cursor will be put into the right place depending on the data.
"""
function Preamble(io, ::Type{T}) where {T}
    start = position(io)
    cnt = readtype(io, UInt32)
    version = readtype(io, UInt16)
    if Int64(cnt) & Const.kByteCountMask > 0
        cnt = Int64(cnt) & ~Const.kByteCountMask
        return Preamble(start, cnt + 4, version, T)
    else
        seek(io, start)
        version = readtype(io, UInt16)
        return Preamble(start, missing, version, T)
    end
end

function Preamble(io::Cursor, ::Type{T}) where {T}
    Preamble(io.io, T)
end

"""
    function skiptobj(io)

Skips a TObject.
"""
function skiptobj(io)
    version = readtype(io, Int16)
    if Int64(version) & Const.kByteCountMask > 0
        skip(io, 4)
    end
    fUniqueID = readtype(io, UInt32)
    fBits = readtype(io, UInt32)
    if fBits & Const.kIsReferenced > 0
        skip(io, 2)
    end
end

"""
    function endcheck(io, preamble::Preamble)

Checks if everything went well after parsing a TObject. Used in conjunction
with `Preamble`.
"""
function endcheck(io, preamble::T) where {T<:Preamble}
    if !ismissing(preamble.cnt)
        observed = position(io) - preamble.start
        if observed != preamble.cnt
            error("Object '$(preamble.type)' has $(observed) bytes; expected $(preamble.cnt)")
        end
    end
    nothing
end


function _versioned_streamer(io, ::Type{T}) where {T<:ROOTStreamedObject}
    preamble = Preamble(io, T)
    basename = last(split(string(T), "."))
    versioned_name = Symbol(basename, "_$(preamble.version)")
    if !isdefined(@__MODULE__, versioned_name)
        error("Unknown version $(preamble.version) of ROOT type $basename. " *
              "Consider updating UnROOT.jl or filing an issue.")
    end
    preamble, getfield(@__MODULE__, versioned_name)
end

function stream!(io, fields, ::Type{T}; check=true) where {T<:ROOTStreamedObject}
    preamble, streamer = _versioned_streamer(io, T)
    readfields!(io, fields, streamer)
    check && endcheck(io, preamble)
end


abstract type TNamed <: ROOTStreamedObject end
# TODO: we probably should switch over to @kwdef at some point, but that's another big refactoring
# Cursor is not needed here but it's mandatory due to the historical design of UnROOT and the
# parsefields approach
Base.@kwdef struct TNamed_1 <: TNamed
    cursor::Cursor
    fName::String
    fTitle::String
end
function readfields!(io::IO, fields, ::Type{TNamed_1})
    parsefields!(io, fields, TObject)
    fields[:fName] = readtype(io, String)
    fields[:fTitle] = readtype(io, String)
end

abstract type TAttLine <: ROOTStreamedObject end
struct TAttLine_1 <: TAttLine end
function readfields!(io::IO, fields, T::Type{TAttLine_1})
    fields[:fLineColor] = readtype(io, Int16)
    fields[:fLineStyle] = readtype(io, Int16)
    fields[:fLineWidth] = readtype(io, Int16)
end
struct TAttLine_2 <: TAttLine end
function readfields!(io::IO, fields, T::Type{TAttLine_2})
    fields[:fLineColor] = readtype(io, Int16)
    fields[:fLineStyle] = readtype(io, Int16)
    fields[:fLineWidth] = readtype(io, Int16)
end

abstract type TAttFill <: ROOTStreamedObject end
struct TAttFill_1 <: TAttFill end
function readfields!(io::IO, fields, T::Type{TAttFill_1})
    fields[:fFillColor] = readtype(io, Int16)
    fields[:fFillStyle] = readtype(io, Int16)
end
struct TAttFill_2 <: TAttFill end
function readfields!(io::IO, fields, T::Type{TAttFill_2})
    fields[:fFillColor] = readtype(io, Int16)
    fields[:fFillStyle] = readtype(io, Int16)
end

abstract type TAttMarker <: ROOTStreamedObject end
struct TAttMarker_1 <: TAttMarker end
const TAttMarker_2 = TAttMarker_1
const TAttMarker_3 = TAttMarker_1
function readfields!(io::IO, fields, T::Type{TAttMarker_1})
    fields[:fMarkerColor] = readtype(io, Int16)
    fields[:fMarkerStyle] = readtype(io, Int16)
    fields[:fMarkerSize] = readtype(io, Float32)
end

struct MmapStream
    mmap_ary::Vector{UInt8}
end
end
