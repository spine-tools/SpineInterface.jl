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

# Time slice map
struct TimeSliceMap
    time_slices::Array{TimeSlice,1}
    time_slice_map::Array{Int64,1}
end

function TimeSliceMap(time_slices::Array{TimeSlice,1})
    map_start = start(first(time_slices))
    map_end = end_(last(time_slices))
    time_slice_map = Array{Int64,1}(undef, Minute(map_end - map_start).value)
    for (ind, t) in enumerate(time_slices)
        first_minute = Minute(start(t) - map_start).value + 1
        last_minute = Minute(end_(t) - map_start).value
        time_slice_map[first_minute:last_minute] .= ind
    end
    TimeSliceMap(time_slices, time_slice_map)
end

function map_indices(h::TimeSliceMap, t::TimeSlice...)
    mapped = Array{Int64,1}()
    map_start = start(first(h.time_slices))
    map_end = end_(last(h.time_slices))
    for s in t
        s_start = max(map_start, start(s))
        s_end = min(map_end, end_(s))
        s_end <= s_start && continue
        first_ind = h.time_slice_map[Minute(s_start - map_start).value + 1]
        last_ind = h.time_slice_map[Minute(s_end - map_start).value]
        append!(mapped, collect(first_ind:last_ind))
    end
    unique(mapped)
end

function map_indices(h::TimeSliceMap, t::DateTime...)
    map_start = start(first(h.time_slices))
    map_end = end_(last(h.time_slices))
    unique(h.time_slice_map[Minute(s - map_start).value + 1] for s in t if map_start <= s < map_end)
end

(h::TimeSliceMap)(t::Union{TimeSlice,DateTime}...) = [h.time_slices[ind] for ind in map_indices(h, t...)]