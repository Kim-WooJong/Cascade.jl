"""Producer-only assembly in original branch/basket order, using old reader rules."""
function assemble_decoded_basket!(plan, state, descriptor, basket)
    lo = descriptor.lo; hi = descriptor.hi; n = hi-lo+1
    if descriptor.skip
        plan.jagged || fill!(view(state.values, lo:hi), zero(plan.E))
        return nothing
    end
    length(basket) == n || error("basket entry count mismatch: $(plan.name)")
    if !plan.jagged
        copyto!(state.values, lo, basket, 1, n)
    elseif plan.masked
        dst = plan.offsets[lo]; m = plan.offsets[hi+1]-dst
        if _flat_basket(basket)
            length(basket.data) == m || error("basket content does not match counter branch: $(plan.name)")
            copyto!(state.values, dst+1, basket.data, 1, m)
        else
            for (k,v) in enumerate(basket)
                e = lo+k-1
                length(v) == plan.offsets[e+1]-plan.offsets[e] || error("event length mismatch with counter")
                copyto!(state.values, plan.offsets[e]+1,v,1,length(v))
            end
        end
    elseif _flat_basket(basket)
        base = state.offsets[lo]
        append!(state.values, basket.data)
        for k in 1:n
            state.offsets[lo+k] = base + Int(basket.elem_ptr[k+1])-1
        end
    else
        for (k,v) in enumerate(basket)
            append!(state.values,v)
            state.offsets[lo+k] = state.offsets[lo+k-1]+length(v)
        end
    end
    return nothing
end
