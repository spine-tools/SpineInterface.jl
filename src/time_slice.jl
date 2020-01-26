#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of Spine Model.
#
# Spine Model is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Spine Model is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

import Dates: CompoundPeriod

"""
    TimeSlice

A type for representing a slice of time.
"""
struct TimeSlice <: ObjectLike
    start::Ref{DateTime}
    end_::Ref{DateTime}
    duration::Float64
    blocks::NTuple{N,Object} where N
    immutableid::UInt64
    function TimeSlice(start, end_, duration, blocks)
        start > end_ && error("out of order")
        immutableid = objectid((start, end_, duration, blocks))
        new(Ref(start), Ref(end_), duration, blocks, immutableid)
    end
end

"""
    TimeSlice(start::DateTime, end_::DateTime)

Construct a `TimeSlice` with bounds given by `start` and `end_`.
"""
function TimeSlice(start::DateTime, end_::DateTime, blocks::Object...; duration_unit=Minute)    
    dur = Minute(end_ - start) / Minute(duration_unit(1))
    TimeSlice(start, end_, dur, blocks)
end

TimeSlice(other::TimeSlice) = other

Base.show(io::IO, t::TimeSlice) = print(io, "$(start(t)) 🡒 $(end_(t))")

"""
    duration(t::TimeSlice)

The duration of time slice `t` in minutes.
"""
duration(t::TimeSlice) = t.duration

start(t::TimeSlice) = t.start[]
end_(t::TimeSlice) = t.end_[]
blocks(t::TimeSlice) = t.blocks

Base.isless(a::TimeSlice, b::TimeSlice) = tuple(start(a), end_(a)) < tuple(start(b), end_(b))

function Base.:(==)(a::TimeSlice, b::TimeSlice)
    start(a) == start(b) && end_(a) == end_(b) && blocks(a) == blocks(b) && duration(a) == duration(b)
end

Base.objectid(t::TimeSlice) = t.immutableid

"""
    before(a::TimeSlice, b::TimeSlice)

Determine whether the end point of `a` is exactly the start point of `b`.
"""
before(a::TimeSlice, b::TimeSlice) = start(b) == end_(a)


"""
    iscontained(b::TimeSlice, a::TimeSlice)

Determine whether `b` is contained in `a`.
"""
iscontained(b::TimeSlice, a::TimeSlice) = start(b) >= start(a) && end_(b) <= end_(a)
iscontained(b::DateTime, a::TimeSlice) = start(a) <= b <= end_(a)

"""
    overlaps(a::TimeSlice, b::TimeSlice)

Determine whether `a` and `b` overlap.
"""
overlaps(a::TimeSlice, b::TimeSlice) = start(a) <= start(b) < end_(a) || start(b) <= start(a) < end_(b)

"""
    overlap_duration(a::TimeSlice, b::TimeSlice)

The number of minutes where `a` and `b` overlap.
"""
function overlap_duration(a::TimeSlice, b::TimeSlice)
    overlaps(a, b) || return 0.0
    overlap_start = max(start(a), start(b))
    overlap_end = min(end_(a), end_(b))
    duration(a) * Minute(overlap_end - overlap_start) / Minute(end_(a) - start(a))
end

# Iterate single `TimeSlice` as if it were a one-element collection.
Base.iterate(t::TimeSlice) = iterate((t,))
Base.iterate(t::TimeSlice, state::T) where T = iterate((t,), state)
Base.length(t::TimeSlice) = 1

# Convenience subtraction operator
function Base.:-(t::TimeSlice, p::Period)
    new_start = start(t) - p
    new_end = end_(t) - p
    TimeSlice(new_start, new_end, duration(t), blocks(t))
end

function roll!(t::TimeSlice, forward::Union{Period,CompoundPeriod})
    t.start[] += forward
    t.end_[] += forward
    t
end

Base.intersect(s::Array{TimeSlice,1}, ::Anything) = s

function Base.intersect(s::Array{TimeSlice,1}, s2)
    if issorted(s) && issorted(s2)
        intersectsorted(s, s2)
    else
        invoke(intersect, Tuple{AbstractArray,typeof(s2)}, s, s2)
    end
end

#=
IDEA: Try and use `TimeSlice.blocks`. Not very good at the moment

"""
    block_time_slices(s::Array{TimeSlice,1})

A `Dict` mapping temporal blocks to time slices in `s`.
"""
function block_time_slices(s::Array{TimeSlice,1})
    block_time_slices = Dict{Object,Array{TimeSlice,1}}()
    for t in s
        for blk in t.blocks
            push!(get!(block_time_slices, blk, TimeSlice[]), t)
        end
    end
    block_time_slices
end

function Base.intersect(s::Array{TimeSlice,1}, s2::Array{TimeSlice,1})
    block_s = block_time_slices(s)
    block_s2 = block_time_slices(s2)
    result = []
    for k in intersect(keys(block_s), keys(block_s2))
        v = block_s[k]
        v2 = block_s2[k]
        if issorted(v) && issorted(v2)
            append!(result, intersectsorted(v, v2))
        else
            append!(result, invoke(intersect, Tuple{AbstractArray,AbstractArray}, v, v2))
        end
    end
    unique(result)
end
=#

function intersectsorted(s::Array{T,1}, s2) where T
    result = Array{T,1}()
    sizehint!(result, length(s))
    it = iterate(s)
    it2 = iterate(s2)
    while it != nothing && it2 != nothing
        i, t = it
        i2, t2 = it2
        if i > i2
            it2 = _groupediterate(s2, t2, i2)
        elseif i2 > i
            it = _groupediterate(s, t, i)
        else  # i == i2
            push!(result, i)
            it = _groupediterate(s, t, i)
            it2 = _groupediterate(s2, t2, i2)
        end
    end
    result
end

function Base.unique(s::Array{TimeSlice,1})
    if issorted(s)
        uniquesorted(s)
    else
        invoke(unique, Tuple{AbstractArray}, s)
    end
end

function uniquesorted(s::Array{T,1}) where T
    result = Array{T,1}()
    sizehint!(result, length(s))
    it = iterate(s)
    while it != nothing
        i, t = it
        push!(result, i)
        it = _groupediterate(s, t, i)
    end
    result
end

"""
    _groupediterate(s, t, ref)

Advance the iterator to obtain the next element different than `ref`
"""
function _groupediterate(s, t, ref)
    it = iterate(s, t)
    while true
        it === nothing && break
        i, t = it
        i != ref && break
        it = iterate(s, t)
    end
    it
end


"""
    t_lowest_resolution(t_itr)

An `Array` holding only the lowest resolution `TimeSlice`s from `t_itr` (those that are not contained in any other).
"""
function t_lowest_resolution(t_arr::Array{TimeSlice,1})
    isempty(t_arr) && return TimeSlice[]
    t_arr = sort(t_arr)
    result = [t_arr[1]]
    for t in Iterators.drop(t_arr, 1)
        if iscontained(result[end], t)
            result[end] = t
        elseif !iscontained(t, result[end])
            push!(result, t)
        end
    end
    result
end

t_lowest_resolution(t_iter) = isempty(t_iter) ? [] : t_lowest_resolution(collect(t_iter))

"""
    t_highest_resolution(t_itr)

An `Array` holding only the highest resolution `TimeSlice`s from `t_itr` (those that do not contain any other).
"""
function t_highest_resolution(t_arr::Array{TimeSlice,1})
    isempty(t_arr) && return TimeSlice[]
    t_arr = sort(t_arr)
    result = [t_arr[1]]
    for t in Iterators.drop(t_arr, 1)
        iscontained(result[end], t) || push!(result, t)
    end
    result
end

t_highest_resolution(t_iter) = isempty(t_iter) ? [] : t_highest_resolution(collect(t_iter))
