#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpineInterface.
#
# SpineInterface is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineInterface is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################
import Dates: CompoundPeriod

"""
    duration(t::TimeSlice)

The duration of time slice `t`.
"""
duration(t::TimeSlice) = t.duration

"""
    start(t::TimeSlice)

The start of time slice or time slice map `t` as the referenced `DateTime`.
"""
start(t::TimeSlice) = t.start[]

"""
    startref(t::TimeSlice)

A reference to the start of time slice `t`.
"""
startref(t::TimeSlice) = _StartRef(t)

"""
    end_(t::TimeSlice)

The end of time slice or time slice map `t`.
"""
end_(t::TimeSlice) = t.end_[]

"""
    blocks(t::TimeSlice)

The temporal blocks where time slice `t` is found.
"""
blocks(t::TimeSlice) = t.blocks

"""
    before(a::TimeSlice, b::TimeSlice)

Determine whether the end point of `a` is exactly the start point of `b`.
"""
before(a::TimeSlice, b::TimeSlice) = start(b) == end_(a)

"""
    iscontained(b, a)

Determine whether `b` is contained in `a`.
"""
iscontained(b::TimeSlice, a::TimeSlice) = start(b) >= start(a) && end_(b) <= end_(a)
iscontained(b::DateTime, a::TimeSlice) = start(a) <= b <= end_(a)

contains(a, b) = iscontained(b, a)

"""
    overlaps(a, b)

Determine whether `a` and `b` overlap.
"""
overlaps(a::TimeSlice, b::TimeSlice) = start(a) <= start(b) < end_(a) || start(b) <= start(a) < end_(b)
function overlaps(t::TimeSlice, union::UnionOfIntersections)
    component_enclosing_rounding = Dict(
        :Y => (year, x -> 0, Year),
        :M => (month, year, Month),
        :D => (day, month, Day),
        :WD => (dayofweek, week, Day),
        :h => (hour, day, Hour),
        :m => (minute, hour, Minute),
        :s => (second, minute, Second),
    )
    for intersection in union
        does_overlap = true
        for interval in intersection
            component, enclosing, rounding = component_enclosing_rounding[interval.key]
            # Compute component and enclosing component for both start and end of time slice.
            # In the comments below, we assume component is hour, and thus enclosing component is day
            # (but of course, we don't use this assumption in the code itself!)
            t_start, t_end = floor(start(t), rounding), ceil(end_(t), rounding)
            t_lower = component(t_start)
            t_upper = component(t_end)
            t_lower_enclosing = enclosing(t_start)
            t_upper_enclosing = enclosing(t_end)
            if interval.key in (:h, :m, :s)
                # Convert from 0-based to 1-based
                t_lower += 1
                t_upper += 1
            end
            if t_upper_enclosing == t_lower_enclosing
                # Time slice starts and ends on the same day
                # We just need to check whether the time slice and the interval overlap
                if !(interval.lower <= t_lower <= interval.upper || t_lower <= interval.lower < t_upper)
                    does_overlap = false
                    break
                end
            elseif t_upper_enclosing == t_lower_enclosing + 1
                # Time slice goes through the day boundary
                # We just need to check that time slice doesn't start after the interval ends on the first day,
                # or ends before the interval starts on the second day
                if t_lower > interval.upper && t_upper <= interval.lower
                    does_overlap = false
                    break
                end
                # Time slice spans more than one day
                # Nothing to do, time slice will always contain the interval
            end
        end
        does_overlap && return true
    end
    false
end

"""
    overlap_duration(a::TimeSlice, b::TimeSlice)

The duration of the period where `a` and `b` overlap.
"""
function overlap_duration(a::TimeSlice, b::TimeSlice)
    overlaps(a, b) || return 0.0
    overlap_start = max(start(a), start(b))
    overlap_end = min(end_(a), end_(b))
    duration(a) * (Minute(overlap_end - overlap_start) / Minute(end_(a) - start(a)))
end

"""
    roll!(t::TimeSlice, forward::Union{Period,CompoundPeriod}; update::Bool=true)

Roll the given `t` in time by the period specified by `forward`.
"""
function roll!(t::TimeSlice, forward::Union{Period,CompoundPeriod}; update::Bool=true)
    t.start[] += forward
    t.end_[] += forward
    if update
        for timeout in collect(keys(t.callbacks))
            callbacks = pop!(t.callbacks, timeout)
            timeout -= forward
            if Dates.toms(forward) < 0 || Dates.toms(timeout) <= 0
                for callback in callbacks
                    callback()
                end
            else
                t.callbacks[timeout] = callbacks
            end
        end
    end
    t
end

"""
    t_lowest_resolution!(t_coll)

Remove time slices that are contained in any other from `t_coll`, and return the modified `t_coll`.
"""
t_lowest_resolution!(t_coll::Union{Array{TimeSlice,1},Dict{TimeSlice,T}}) where T = _deleteat!(contains, t_coll)

"""
    t_highest_resolution!(t_coll)

Remove time slices that contain any other from `t_coll`, and return the modified `t_coll`.
"""
t_highest_resolution!(t_coll::Union{Array{TimeSlice,1},Dict{TimeSlice,T}}) where T = _deleteat!(iscontained, t_coll)

"""
    t_highest_resolution(t_iter)

Return an `Array` containing only time slices from `t_iter` that do not contain any other.
"""
t_highest_resolution(t_iter) = t_highest_resolution!(collect(TimeSlice, t_iter))

"""
    t_lowest_resolution(t_iter)

Return an `Array` containing only time slices from `t_iter` that aren't contained in any other.
"""
t_lowest_resolution(t_iter) = t_lowest_resolution!(collect(TimeSlice, t_iter))

"""
    t_lowest_resolution_sets!(mapping)

Modify the given `Dict` (which must be a mapping from `TimeSlice` to `Set`) in place,
so that if key `t1` is contained in key `t2`, then the former is removed and its value is merged into the latter's.
"""
t_lowest_resolution_sets!(mapping) = _compress!(contains, mapping)

"""
    t_highest_resolution_sets!(mapping)

Modify the given `Dict` (which must be a mapping from `TimeSlice` to `Set`) in place,
so that if key `t1` contains key `t2`, then the former is removed and its value is merged into the latter's.
"""
t_highest_resolution_sets!(mapping) = _compress!(iscontained, mapping)

"""
    _deleteat!(t_coll, func)

Remove key `k` in given collection if `func(t_coll[k], t_coll[l])` is `true` for any `l` other than `k`.
Used by `t_lowest_resolution` and `t_highest_resolution`.
"""
function _deleteat!(func, t_coll::Union{Array{K,1},Dict{K,T}}) where {K,T}
    n = length(t_coll)
    n <= 1 && return t_coll
    _do_deleteat!(func, t_coll)
end

function _do_deleteat!(func, t_arr::Array{K,1}) where K
    remove = _any_other(func, t_arr)
    deleteat!(t_arr, remove)
end
function _do_deleteat!(func, t_dict::Dict{K,T}) where {K,T}
    keys_ = collect(keys(t_dict))
    remove = _any_other(func, keys_)
    keep = .!remove
    keys_to_remove = deleteat!(keys_, keep)
    for k in keys_to_remove
        delete!(t_dict, k)
    end
    t_dict
end

"""
    _any_other(func, t_arr)

An `Array` of `Bool` values, where position `i` is `true` if `func(t_arr[i], t_arr[j])` is `true` for any `j` other
than `i`.
"""
function _any_other(func, t_arr::Array{T,1}) where T
    n = length(t_arr)
    result = [false for i in 1:n]
    for i in 1:n
        result[i] && continue
        t_i = t_arr[i]
        for j in Iterators.flatten((1:(i - 1),  (i + 1):n))
            result[j] && continue
            t_j = t_arr[j]
            if func(t_i, t_j)
                result[j] = true
            end
        end
    end
    result
end

function _compress!(func, d::Dict{K,V}) where {K,V}
    for (key, value) in d
        for other_key in setdiff(keys(d), key)
            if func(key, other_key)
                union!(value, pop!(d, other_key))
            end
        end
    end
    d
end