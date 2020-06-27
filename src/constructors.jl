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

Object(name::AbstractString, args...) = Object(Symbol(name), args...)
Object(name::Symbol) = Base.invokelatest(Object, name)  # NOTE: this allows us to override `Object` in `using_spinedb`

ObjectClass(name, objects, vals) = ObjectClass(name, objects, vals, Dict())
ObjectClass(name, objects) = ObjectClass(name, objects, Dict())

RelationshipClass(name, obj_cls_names, rels, vals) = RelationshipClass(name, obj_cls_names, rels, vals, Dict())
RelationshipClass(name, obj_cls_names, rels) = RelationshipClass(name, obj_cls_names, rels, Dict())

Parameter(name) = Parameter(name, [])

"""
    TimeSlice(start::DateTime, end_::DateTime)

Construct a `TimeSlice` with bounds given by `start` and `end_`.
"""
function TimeSlice(start::DateTime, end_::DateTime, blocks::Object...; duration_unit=Minute)
    dur = Minute(end_ - start) / Minute(duration_unit(1))
    TimeSlice(start, end_, dur, blocks)
end

Map(inds::Array{String,1}, vals::Array{V,1}) where V = Map(Symbol.(inds), vals)
Map(inds::Array{DateTime_,1}, vals::Array{V,1}) where V = Map([ind.value for ind in inds], vals)
function Map(inds::Array{DateTime_,1}, vals::Array{V,1}) where V <: Real
    TimeSeries([ind.value for ind in inds], _first.(vals), false, false)
end
function Map(inds::Array{K,1}, vals::Array{V,1}) where {K,V}
    mapping = Dict{K,Array{V,1}}()
    sizehint!(mapping, length(inds))
    for (ind, val) in zip(inds, vals)
        push!(get!(mapping, ind, []), val)
    end
    Map(mapping)
end

"""
    PeriodCollection(spec::String)

Construct a `PeriodCollection` from the given string specification.
"""
function PeriodCollection(spec::String)
    union_op = ","
    intersection_op = ";"
    range_op = "-"
    kwargs = Dict()
    regexp = r"(Y|M|D|WD|h|m|s)"
    for intervals in split(spec, union_op)
        for interval in split(intervals, intersection_op)
            m = Base.match(regexp, interval)
            m === nothing && error("invalid interval specification $interval.")
            key = m.match
            start_stop = interval[length(key)+1:end]
            start_stop = split(start_stop, range_op)
            length(start_stop) != 2 && error("invalid interval specification $interval.")
            start_str, stop_str = start_stop
            start = try
                parse(Int64, start_str)
            catch ArgumentError
                error("invalid lower bound $start_str.")
            end
            stop = try
                parse(Int64, stop_str)
            catch ArgumentError
                error("invalid upper bound $stop_str.")
            end
            start > stop && error("lower bound can't be higher than upper bound.")
            arr = get!(kwargs, Symbol(key), Array{UnitRange{Int64},1}())
            push!(arr, range(start, stop=stop))
        end
    end
    PeriodCollection(;kwargs...)
end

function TimeSliceMap(time_slices::Array{TimeSlice,1})
    map_start = start(first(time_slices))
    map_end = end_(last(time_slices))
    index_size = Minute(map_end - map_start).value
    last_ind = length(time_slices)
    index = fill(last_ind, index_size)  # Init index with the last so we can skip the last time slice in the loop below
    for (ind, (t, next_t)) in enumerate(zip(time_slices[1:end - 1], time_slices[2:end]))
        from_minute, to_minute = _from_to_minute(map_start, start(t), start(next_t))
        index[from_minute:to_minute] .= ind
    end
    TimeSliceMap(time_slices, index, map_start, map_end)
end

function TimeSeriesMap(stamps::Array{DateTime,1})
    map_start = first(stamps)
    map_end = last(stamps)
    index = Array{Int64,1}(undef, Minute(map_end - map_start).value)
    for (ind, (start, end_)) in enumerate(zip(stamps[1:end - 1], stamps[2:end]))
        from_minute, to_minute = _from_to_minute(map_start, start, end_)
        index[from_minute] = ind
        index[from_minute + 1:to_minute] .= ind + 1
    end
    last_ind = length(stamps)
    append!(index, [last_ind, last_ind + 1])
    TimeSeriesMap(index, map_start, map_end)
end

ScalarParameterValue(s::String) = ScalarParameterValue(Symbol(s))

function TimeSeriesParameterValue(ts::TimeSeries{V}) where {V}
    t_map = TimeSeriesMap(ts.indexes)
    if ts.repeat
        span = ts.indexes[end] - ts.indexes[1]
        valsum = sum(ts.values)
        len = length(ts.values)
        RepeatingTimeSeriesParameterValue(ts, span, valsum, len, t_map)
    else
        StandardTimeSeriesParameterValue(ts, t_map)
    end
end

# TODO: specify PyObject constructors for other types?
PyObject(x::DateTime_) = @pycall db_api.DateTime(x.value)::PyObject
PyObject(x::Duration) = @pycall db_api.Duration(_period_to_duration_string(x.value))::PyObject
PyObject(x::Array_) = @pycall db_api.Array(PyVector(x.value))::PyObject
function PyObject(x::TimePattern)
    indexes = [_period_collection_to_time_pattern_string(k) for k in keys(x)]
    @pycall db_api.TimePattern(indexes, collect(values(x)))::PyObject
end
function PyObject(ts::TimeSeries)
    @pycall db_api.TimeSeriesVariableResolution(ts.indexes, ts.values, ts.ignore_year, ts.repeat)::PyObject
end

Call(n) = IdentityCall(n)
Call(op::Function, args::Tuple) = OperatorCall(op, args)
Call(param::Parameter, kwargs::NamedTuple) = ParameterCall(param, kwargs)
Call(other::Call) = copy(other)
