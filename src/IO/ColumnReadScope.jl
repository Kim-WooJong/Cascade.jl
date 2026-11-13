"""Invocation-local slots: slot one is borrowed; extra slots are owned.

Slots belong to worker tasks, never thread IDs. No decoded columns are cached.
Operation functions are an internal ownership-test seam, not reader plugins.
"""
mutable struct ColumnReadScope
    original::Any
    width::Int
    slots::Vector{Any}
    opener::Any
    closer::Any
    readbranch::Any
    verify::Any
    diagnostics::Dict{String,Any}
    lock::ReentrantLock
    active::Int
end
