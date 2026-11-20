# Opt-in task-owned raw destinations. All raw references must die before reuse.
# Capacity is retained explicitly and exact replacement bounds growth.
function reusable_destination!(d::StreamDecodeState, name::String, ::Type{E}, n::Int, clear::Bool) where {E}
    n >= 0 || error("negative reusable destination length")
    if !d.reuse_destinations
        v = Vector{E}(undef,n)
        clear && fill!(v,zero(E))
        return v, sizeof(v)
    end
    slot = get(d.destinations,name,nothing)
    allocated = 0
    if !(slot isa Tuple{Vector{E},Int}) || slot[2] < n
        old = slot === nothing ? 0 : Base.checked_mul(sizeof(eltype(slot[1])),slot[2])
        newbytes = Base.checked_mul(sizeof(E),n)
        projected = Base.checked_add(d.destination_reserved,newbytes-old)
        projected <= d.destination_limit || error("reusable destination capacity exceeds stream_window_bytes before allocation")
        v = Vector{E}(undef,n)
        d.destinations[name] = (v,n)
        allocated = sizeof(v)
        d.destination_reserved = Base.checked_add(d.destination_reserved,allocated-old)
    else
        v = slot[1]
    end
    return _reset_reusable_destination!(v,n,clear), allocated
end
function _reset_reusable_destination!(v::Vector{E}, n::Int, clear::Bool) where {E}
    resize!(v,n)
    clear && fill!(v,zero(E))
    return v
end

function reusable_destination_reservation(r)
    total=Int128(0)
    for br in values(r.branches)
        peak=Int128(0)
        for range in r.windows
            bytes=br.jagged ? sum((Int128(br.baskets[i].decoded) for i in stream_basket_overlap(br.baskets,range));init=Int128(0)) : Int128(sizeof(br.E))*length(range)
            peak=max(peak,bytes)
        end
        total=Base.checked_add(total,peak)
    end
    return total
end
