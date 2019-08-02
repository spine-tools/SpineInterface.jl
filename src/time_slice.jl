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
"""
    TimeSlice

A type for representing a slice of time.
"""
struct TimeSlice <: ObjectLike
    start::DateTime
    end_::DateTime
    duration::Period
    blocks::Tuple
    JuMP_name::String
    TimeSlice(x, y, blk, n) = x > y ? error("out of order") : new(x, y, Minute(y - x), blk, n)
end

"""
    TimeSlice(start::DateTime, end_::DateTime)

Construct a `TimeSlice` with bounds given by `start` and `end_`.
"""
TimeSlice(start::DateTime, end_::DateTime, blocks::Object...) = TimeSlice(start, end_, blocks, "$start...$end_")
TimeSlice(other::TimeSlice) = other

Base.show(io::IO, time_slice::TimeSlice) = print(io, time_slice.JuMP_name)

"""
    duration(t::TimeSlice)

The duration of time slice `t` in minutes.
"""
duration(t::TimeSlice) = t.duration.value

start(t::TimeSlice) = t.start
end_(t::TimeSlice) = t.end_
blocks(t::TimeSlice) = t.blocks

Base.isless(a::TimeSlice, b::TimeSlice) = tuple(a.start, a.end_) < tuple(b.start, b.end_)


"""
    before(a::TimeSlice, b::TimeSlice)

Determine whether the end point of `a` is exactly the start point of `b`.
"""
before(a::TimeSlice, b::TimeSlice) = b.start == a.end_


"""
    iscontained(b::TimeSlice, a::TimeSlice)

Determine whether `b` is contained in `a`.
"""
iscontained(b::TimeSlice, a::TimeSlice) = b.start >= a.start && b.end_ <= a.end_
iscontained(b::DateTime, a::TimeSlice) = a.start <= b <= a.end_

"""
    overlaps(a::TimeSlice, b::TimeSlice)

Determine whether `a` and `b` overlap.
"""
overlaps(a::TimeSlice, b::TimeSlice) = a.start <= b.start < a.end_ || b.start <= a.start < b.end_

"""
    overlap_duration(a::TimeSlice, b::TimeSlice)

The number of minutes where `a` and `b` overlap.
"""
function overlap_duration(a::TimeSlice, b::TimeSlice)
    overlaps(a, b) || return 0
    overlap_start = max(a.start, b.start)
    overlap_end = min(a.end_, b.end_)
    Minute(overlap_end - overlap_start).value
end

# Iterate single `TimeSlice` as if it were a one-element collection.
Base.iterate(t::TimeSlice) = iterate((t,))
Base.iterate(t::TimeSlice, state::T) where T = iterate((t,), state)
Base.length(t::TimeSlice) = 1

# Convenience subtraction operator
Base.:-(t::TimeSlice, p::Period) = TimeSlice(t.start - p, t.end_ - p)

# Custom intersect: up to 10 times faster for sorted inputs
Base.intersect(s::Array{TimeSlice,1}, ::Anything) = s

function Base.intersect(s::Array{TimeSlice,1}, s2)
    if issorted(s) && issorted(s2)
        intersectsorted(s, s2)
    else
        invoke(intersect, Tuple{AbstractArray,typeof(s2)}, s, s2)
    end
end

function Base.unique(s::Array{TimeSlice,1})
    if issorted(s)
        uniquesorted(s)
    else
        invoke(unique, Tuple{AbstractArray}, s)
    end
end

function uniquesorted(s::Array{T,1}) where T
    result = T[]
    sizehint!(result, length(s))
    it = iterate(s)
    while it != nothing
        i, t = it
        push!(result, i)
        it = _groupediterate(s, t, i)
    end
    result
end

function intersectsorted(s::Array{T,1}, s2) where T
    result = T[]
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
    t_lowest_resolution(t_arr::Array{TimeSlice,1})

An `Array` with the `TimeSlice`s from `t_arr` that are not contained in any other.
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
    t_highest_resolution(t_arr::Array{TimeSlice,1})

An `Array` with the `TimeSlice`s from `t_arr` that do not contain any other.
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
