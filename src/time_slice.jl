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
    id::UInt64
    function TimeSlice(start, end_, duration, blocks)
        start > end_ && error("out of order")
        id = objectid((start, end_, duration, blocks))
        new(Ref(start), Ref(end_), duration, blocks, id)
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

#function Base.:(==)(a::TimeSlice, b::TimeSlice)
#    start(a) == start(b) && end_(a) == end_(b) && blocks(a) == blocks(b) && duration(a) == duration(b)
#end

Base.:(==)(a::TimeSlice, b::TimeSlice) = a.id == b.id

Base.hash(t::TimeSlice) = t.id

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


