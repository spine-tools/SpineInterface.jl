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

"""
    duration(t::TimeSlice)

The duration of time slice `t` as a multiple of the duration unit.
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
startref(t::TimeSlice) = t.start

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
iscontained(b::DateTime, a::TimeSlice) = start(a) <= b < end_(a)

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
    roll!(t::TimeSlice, forward::Union{Period,CompoundPeriod})

Roll the given `t` in time by the period specified by `forward` and returns updates to call.
"""
function roll!(t::TimeSlice, forward::Union{Period,Dates.CompoundPeriod})
    t.start[] += forward
    t.end_[] += forward
    updates = []
    for (upd, timeout) in t.updates
        timeout -= forward
        if Dates.toms(forward) < 0 || Dates.toms(timeout) <= 0
            push!(updates, upd)
        else
            t.updates[upd] = timeout
        end
    end
    updates
end

"""
    collect_updates(t::TimeSlice)

Collect updates registered in the given `t`.
"""
function collect_updates(t::TimeSlice)
    collect(keys(t.updates))
end

function add_roll_hook!(t, fn)
    _add_update(t, Minute(-1), fn)
end

_TimeSliceColl = Union{Vector{TimeSlice},Dict{TimeSlice,V} where V}

"""
    t_lowest_resolution!(t_coll)

Remove time slices that are contained in any other from `t_coll`, and return the modified `t_coll`.
"""
t_lowest_resolution!(t_coll::_TimeSliceColl) = _t_extreme_resolution!(t_coll, :lowest)

"""
    t_lowest_resolution(t_iter)

Return an `Array` containing only time slices from `t_iter` that aren't contained in any other.
"""
t_lowest_resolution(t_iter) = t_lowest_resolution!(collect(TimeSlice, t_iter))

"""
    t_highest_resolution!(t_coll)

Remove time slices that contain any other from `t_coll`, and return the modified `t_coll`.
"""
t_highest_resolution!(t_coll::_TimeSliceColl) = _t_extreme_resolution!(t_coll, :highest)

"""
    t_highest_resolution(t_iter)

Return an `Array` containing only time slices from `t_iter` that do not contain any other.
"""
t_highest_resolution(t_iter) = t_highest_resolution!(collect(TimeSlice, t_iter))

"""
    t_lowest_resolution_sets!(mapping)

Modify the given `Dict` (which must be a mapping from `TimeSlice` to `Set`) in place,
so that if key `t1` is contained in key `t2`, then the former is removed and its value is merged into the latter's.
"""
t_lowest_resolution_sets!(mapping) = _t_extreme_resolution_sets!(mapping, :lowest)

"""
    t_highest_resolution_sets!(mapping)

Modify the given `Dict` (which must be a mapping from `TimeSlice` to `Set`) in place,
so that if key `t1` contains key `t2`, then the former is removed and its value is merged into the latter's.
"""
t_highest_resolution_sets!(mapping) = _t_extreme_resolution_sets!(mapping, :highest)

function _t_extreme_resolution!(t_arr::Vector{TimeSlice}, extreme)
    deleteat!(t_arr, first.(_k_extreme_resolution_k(t_arr, extreme)))
end
function _t_extreme_resolution!(t_dict::Dict{TimeSlice,V}, extreme) where V
    for (k, _x_res_k) in _k_extreme_resolution_k(t_dict, extreme)
        delete!(t_dict, k)
    end
    t_dict
end

function _t_extreme_resolution_sets!(mapping, extreme)
    for (k, x_res_k) in _k_extreme_resolution_k(mapping, extreme)
        union!(mapping[x_res_k], pop!(mapping, k))
    end
    mapping
end

"""
    _k_extreme_resolution_k(t_coll, extreme)

An array where each element is a tuple of two keys in `t_coll`,
the first 'dominated' by the second according to `extreme`.
Extreme can either be `:highest` or `:lowest`.
If `extreme` is `:highest`, then the first element in each returned tuple
contains the second and the second doesn't contain any other.
Conversely, if `extreme` is `:lowest`, then the first element in each returned tuple
is contained in the second and the second is not contained in any other.
"""
function _k_extreme_resolution_k(t_coll::_TimeSliceColl, extreme::Symbol)
    isempty(t_coll) && return ()
    k_t_by_dur = Dict()
    for (k, t) in _k_t_iter(t_coll)
        push!(get!(k_t_by_dur, t.actual_duration, []), (k, t))
    end
    length(k_t_by_dur) == 1 && return ()
    rev = Dict(:lowest => true, :highest => false)[extreme]
    fn = Dict(:lowest => contains, :highest => iscontained)[extreme]
    sorted_durations = sort(collect(keys(k_t_by_dur)); rev=rev)
    extreme_resolution_k_t = pop!(k_t_by_dur, popfirst!(sorted_durations))
    k_extreme_resolution_k = []
    while !isempty(k_t_by_dur)
        more_extreme_resolution_k_t = []
        for (k, t) in pop!(k_t_by_dur, popfirst!(sorted_durations))
            found = false
            for (dom_k, dom_t) in extreme_resolution_k_t
                if fn(dom_t, t)
                    push!(k_extreme_resolution_k, (k, dom_k))
                    found = true
                    break
                end
            end
            found && continue
            push!(more_extreme_resolution_k_t, (k, t))
        end
        append!(extreme_resolution_k_t, more_extreme_resolution_k_t)
    end
    k_extreme_resolution_k
end

_k_t_iter(t_arr::Vector{TimeSlice}) = enumerate(t_arr)
_k_t_iter(t_dict::Dict{TimeSlice,V}) where V = ((t, t) for t in keys(t_dict))
