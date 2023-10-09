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
    parameter_value(parsed_db_value)

A `ParameterValue` from the given parsed db value.
"""
parameter_value(value::String) = parameter_value(Symbol(value))
parameter_value(value::Union{_Scalar,Array,TimePattern,TimeSeries}) = ParameterValue(value)
parameter_value(value::Map) = ParameterValue(Map(value.indexes, parameter_value.(value.values)))
parameter_value(value::T) where {T} = error("can't parse $value of unrecognized type $T")
parameter_value(x::T) where {T<:ParameterValue} = x

"""
    indexed_values(value)

A Dict mapping indexes to inner values.
In case of a scalar - non-indexed - value, the result is Dict(nothing => value).
In case of `Map`, each key in the result is a tuple of all the indexes leading to a value.
"""
indexed_values(pval::ParameterValue) = indexed_values(pval.value)
indexed_values(value) = Dict(nothing => value)
indexed_values(value::Array) = Dict(enumerate(value))
indexed_values(value::TimePattern) = value
indexed_values(value::TimeSeries) = Dict(zip(value.indexes, value.values))
function indexed_values(value::Map)
    Dict(i => v for (ind, val) in zip(value.indexes, value.values) for (i, v) in indexed_values((ind,), val))
end
indexed_values(prefix, value) = Dict((prefix..., ind) => val for (ind, val) in indexed_values(value))

"""
    collect_indexed_values(d)

A parsed value (TimeSeries, TimePattern, Map, etc.) from a Dict mapping indexes to values.

## Examples

```
@assert collect_indexed_values(indexed_values(ts)) == ts
```

"""
collect_indexed_values(x::Dict{Nothing,V}) where V = x[nothing]
collect_indexed_values(x::Dict{K,V}) where {K<:Integer,V} = [x[i] for i in sort(collect(keys(x)))]
collect_indexed_values(x::TimePattern) = x
function collect_indexed_values(x::Dict{DateTime,V}) where V
    TimeSeries(collect(keys(x)), collect(values(x)), false, false)
end
function collect_indexed_values(x::Dict{K,V}) where {H,K<:Tuple{H,Vararg},V}
    d = Dict{H,Any}()
    for (key, value) in x
        head, tail... = key
        new_key = if isempty(tail)
            nothing
        elseif length(tail) == 1
            first(tail)
        else
            tail
        end
        push!(get!(d, head, Dict{typeof(new_key),typeof(value)}()), new_key => value)
    end
    Map(collect(keys(d)), collect_indexed_values.(values(d)))
end

"""
    parse_time_period(union_str)

A UnionOfIntersections from the given string.
"""
function parse_time_period(union_str::String)
    union_op = ","
    intersection_op = ";"
    range_op = "-"
    union = UnionOfIntersections()
    regexp = r"(Y|M|D|WD|h|m|s)"
    for intersection_str in split(union_str, union_op)
        intersection = IntersectionOfIntervals()
        for interval in split(intersection_str, intersection_op)
            m = Base.match(regexp, interval)
            m === nothing && error("invalid interval specification $interval.")
            key = m.match
            lower_upper = interval[(length(key) + 1):end]
            lower_upper = split(lower_upper, range_op)
            length(lower_upper) != 2 && error("invalid interval specification $interval.")
            lower_str, upper_str = lower_upper
            lower = try
                parse(Int64, lower_str)
            catch ArgumentError
                error("invalid lower bound $lower_str.")
            end
            upper = try
                parse(Int64, upper_str)
            catch ArgumentError
                error("invalid upper bound $upper_str.")
            end
            lower > upper && error("lower bound can't be higher than upper bound.")
            push!(intersection, TimeInterval(Symbol(key), lower, upper))
        end
        push!(union, intersection)
    end
    union
end

"""
    parse_db_value(value, type)

A parsed value (TimeSeries, TimePattern, Map, etc.) from given DB value and type.
"""
parse_db_value(value_and_type::Vector{Any}) = parse_db_value(value_and_type...)
function parse_db_value(value::Vector{UInt8}, type::Union{String,Nothing})
    isempty(value) && return nothing
    _parse_db_value(JSON.parse(String(value)), type)
end
parse_db_value(::Nothing, type) = nothing
parse_db_value(x) = _parse_db_value(x)

function _parse_db_value(value::Dict)
    type = get(value, "type", nothing)
    isnothing(type) ? value : _parse_db_value(value, type)
end
_parse_db_value(value, type::String) = _parse_db_value(value, Val(Symbol(type)))
_parse_db_value(value, ::Nothing) = _parse_db_value(value)
_parse_db_value(value::Dict, ::Val{:date_time}) = _parse_date_time(value["data"])
_parse_db_value(value::Dict, ::Val{:duration}) = _parse_duration(value["data"])
_parse_db_value(value::Dict, ::Val{:time_pattern}) = Dict(parse_time_period(ind) => val for (ind, val) in value["data"])
function _parse_db_value(value::Dict, type::Val{:time_series})
    _parse_db_value(get(value, "index", Dict()), value["data"], type)
end
function _parse_db_value(index::Dict, vals::Array, ::Val{:time_series})
    ignore_year = get(index, "ignore_year", false)
    inds = _collect_ts_indexes(index["start"], index["resolution"], length(vals))
    ignore_year && (inds .-= Year.(inds))
    TimeSeries(inds, _parse_float.(vals), ignore_year, get(index, "repeat", false))
end
function _parse_db_value(index::Dict, data::Union{OrderedDict,Dict}, ::Val{:time_series})
    ignore_year = get(index, "ignore_year", false)
    inds = _parse_date_time.(keys(data))
    ignore_year && (inds .-= Year.(inds))
    vals = _parse_float.(values(data))
    TimeSeries(inds, vals, ignore_year, get(index, "repeat", false))
end
_parse_db_value(value::Dict, type::Val{:array}) = _parse_inner_value.(value["data"], Val(Symbol(value["value_type"])))
function _parse_db_value(::Nothing, data::Array{T,1}, ::Val{:array}) where {T}
    _parse_inner_value.(data, Val(Symbol(_inner_type_str(T))))
end
function _parse_db_value(value::Dict, ::Val{:map})
    raw_inds, raw_vals = _map_inds_and_vals(value["data"])
    inds = _parse_inner_value.(raw_inds, Val(Symbol(value["index_type"])))
    vals = _parse_db_value.(raw_vals)
    Map(inds, vals)
end
_parse_db_value(value::Float64) = isinteger(value) ? Int64(value) : value
_parse_db_value(value) = value

function _parse_date_time(data::String)
    try
        DateTime(data, _db_df)
    catch err
        DateTime(data, _alt_db_df)
    end
end

function _parse_duration(data::String)
    o = match(r"\D", data).offset  # position of first non-numeric character
    quantity, unit = parse(Int64, data[1 : o - 1]), strip(data[o:end])
    key = (startswith(lowercase(unit), "month") || unit == "M") ? 'M' : lowercase(unit[1])
    Dict('s' => Second, 'm' => Minute, 'h' => Hour, 'd' => Day, 'M' => Month, 'y' => Year)[key](quantity)
end

_parse_float(x) = Float64(x)
_parse_float(::Nothing) = NaN

_parse_inner_value(value::String, ::Val{:str}) = value
_parse_inner_value(value::T, ::Val{:float}) where {T<:Number} = _parse_float(value)
_parse_inner_value(value::String, ::Val{:duration}) = _parse_duration(value)
_parse_inner_value(value::String, ::Val{:date_time}) = _parse_date_time(value)

_inner_type_str(::Type{Float64}) = "float"
_inner_type_str(::Type{Symbol}) = "str"
_inner_type_str(::Type{String}) = "str"
_inner_type_str(::Type{DateTime}) = "date_time"
_inner_type_str(::Type{T}) where {T<:Period} = "duration"

function _collect_ts_indexes(start::String, resolution::String, len::Int64)
    inds = DateTime[]
    sizehint!(inds, len)
    stamp = _parse_date_time(start)
    res_iter = _resolution_iterator(resolution)
    for (r, k) in zip(Iterators.cycle(res_iter), 1:len)
        push!(inds, stamp)
        stamp += r
    end
    inds
end

_resolution_iterator(resolution::String) = (_parse_duration(resolution),)
_resolution_iterator(resolution::Array{String,1}) = (_parse_duration(r) for r in resolution)

_map_inds_and_vals(data::Matrix) = data[:,1], data[:,2]
_map_inds_and_vals(data::Array) = (x[1] for x in data), (x[2] for x in data)
_map_inds_and_vals(data::Dict) = keys(data), values(data)


"""
    unparse_db_value(x)

A tuple (DB value, type) from given parsed value.
"""
unparse_db_value(x::ParameterValue) = unparse_db_value(x.value)
unparse_db_value(x) = Vector{UInt8}(_serialize_pv(db_value(x))), _db_type(x)

"""A custom JSONContext that serializes NaN values in complex parameter values as 'NaN'"""
mutable struct _ParameterValueJSONContext <: JSON.Writer.JSONContext
    underlying::JSON.Writer.JSONContext
end

for delegate in (:indent, :delimit, :separate, :begin_array, :end_array, :begin_object, :end_object)
    @eval JSON.Writer.$delegate(ctx::_ParameterValueJSONContext) = JSON.Writer.$delegate(ctx.underlying)
end
Base.write(ctx::_ParameterValueJSONContext, byte::UInt8) = write(ctx.underlying, byte)

JSON.Writer.show_null(ctx::_ParameterValueJSONContext) = print(ctx, "NaN")

function _serialize_pv(obj::Dict)
    io = IOBuffer()
    ctx = _ParameterValueJSONContext(JSON.Writer.CompactContext(io))
    JSON.print(ctx, obj)
    String(take!(io))
end
_serialize_pv(x) = JSON.json(x)

"""
    db_value(x)

A DB value from given parsed value.
"""
db_value(x) = x
db_value(x::Dict) = Dict(k => v for (k, v) in x if k != "type")
db_value(x::DateTime) = Dict("data" => string(Dates.format(x, _db_df)))
db_value(x::T) where {T<:Period} = Dict("data" => _unparse_duration(x))
function db_value(x::Array{T}) where {T}
    Dict{String,Any}("value_type" => _inner_type_str(T), "data" => _unparse_element.(x))
end
function db_value(x::TimePattern)
    Dict{String,Any}("data" => Dict(_unparse_time_pattern(k) => v for (k, v) in x))
end
function db_value(x::TimeSeries)
    Dict{String,Any}(
        "index" => Dict("repeat" => x.repeat, "ignore_year" => x.ignore_year),
        "data" => OrderedDict(_unparse_date_time(i) => v for (i, v) in zip(x.indexes, x.values)),
    )
end
function db_value(x::Map{K,V}) where {K,V}
    Dict{String,Any}(
        "index_type" => _inner_type_str(K),
        "data" => [(i, _unparse_map_value(v)) for (i, v) in zip(x.indexes, x.values)],
    )
end

_unparse_date_time(x::DateTime) = string(Dates.format(x, _db_df))
function _unparse_duration(x::T) where {T<:Period}
    d = Dict(Minute => "m", Hour => "h", Day => "D", Month => "M", Year => "Y")
    suffix = get(d, T, nothing)
    if suffix === nothing
        string(Minute(x).value, "m")
    else
        string(x.value, suffix)
    end
end

_unparse_element(x::Union{Float64,String}) = x
_unparse_element(x::DateTime) = _unparse_date_time(x)
_unparse_element(x::T) where {T<:Period} = _unparse_duration(x)

function _unparse_time_pattern(union::UnionOfIntersections)
    union_op = ","
    intersection_op = ";"
    range_op = "-"
    union_arr = [
        join([string(i.key, i.lower, range_op, i.upper) for i in intersection], intersection_op)
        for intersection in union
    ]
    join(union_arr, union_op)
end

_unparse_map_value(x::ParameterValue) = _unparse_map_value(x.value)
_unparse_map_value(x) = _add_db_type!(db_value(x), x)

function _add_db_type!(db_val::Dict, x)
    db_val["type"] = _db_type(x)
    db_val
end
_add_db_type!(db_val, x) = db_val

_db_type(x) = nothing
_db_type(x::Dict) = x["type"]
_db_type(::DateTime) = "date_time"
_db_type(::T) where {T<:Period} = "duration"
_db_type(x::Array{T}) where {T} = "array"
_db_type(x::TimePattern) = "time_pattern"
_db_type(x::TimeSeries) = "time_series"
_db_type(x::Map{K,V}) where {K,V} = "map"

"""
    timedata_operation(f::Function, x)

Perform `f` element-wise for potentially `TimeSeries`, `TimePattern`, or `Map` argument `x`.
"""
timedata_operation(f::Function, x::TimeSeries) = TimeSeries(x.indexes, f.(x.values), x.ignore_year, x.repeat)
timedata_operation(f::Function, x::TimePattern) = Dict(key => f(val) for (key, val) in x)
timedata_operation(f::Function, x::Number) = f(x)
timedata_operation(f::Function, x::Map) = Map(x.indexes, [timedata_operation(f, val) for val in values(x)])

"""
    timedata_operation(f::Function, x, y)

Perform `f` element-wise for potentially `TimeSeries`, `TimePattern`, or ``Map` arguments `x` and `y`.

If both `x` and `y` are either `TimeSeries` or `TimePattern`, the timestamps of `x` and `y` are combined,
and both time-dependent data are sampled on each timestamps to perform the desired operation.
If either `ts1` or `ts2` are `TimeSeries`, returns a `TimeSeries`.
If either `ts1` or `ts2` has the `ignore_year` or `repeat` flags set to `true`, so does the resulting `TimeSeries`.
For `Map`s, perform recursion until non-map operands are found.

NOTE! Currently, `Map-Map` operations require that `Map` indexes are identical!
"""
timedata_operation(f::Function, x::TimeSeries, y::Number) = TimeSeries(
    x.indexes, f.(x.values, y), x.ignore_year, x.repeat
)
timedata_operation(f::Function, y::Number, x::TimeSeries) = TimeSeries(
    x.indexes, f.(y, x.values), x.ignore_year, x.repeat
)
timedata_operation(f::Function, x::TimePattern, y::Number) = Dict(key => f(val, y) for (key, val) in x)
timedata_operation(f::Function, y::Number, x::TimePattern) = Dict(key => f(y, val) for (key, val) in x)
function timedata_operation(f::Function, x::TimeSeries, y::TimeSeries)
    indexes, values = if x.indexes == y.indexes && !x.ignore_year && !y.ignore_year && !x.repeat && !y.repeat
        x.indexes, broadcast(f, x.values, y.values)
    else
        _timedata_operation(f, x, y)
    end
    ignore_year = x.ignore_year && y.ignore_year
    repeat = x.repeat && y.repeat
    TimeSeries(indexes, values, ignore_year, repeat)
end
function timedata_operation(f::Function, x::TimeSeries, y::TimePattern)
    indexes, values = _timedata_operation(f, x, y)
    TimeSeries(indexes, values, x.ignore_year, x.repeat)
end
function timedata_operation(f::Function, x::TimePattern, y::TimeSeries)
    indexes, values = _timedata_operation(f, x, y)
    TimeSeries(indexes, values, y.ignore_year, y.repeat)
end
function timedata_operation(f::Function, x::TimePattern, y::TimePattern)
    Dict(
        key => f(x_value, y_value)
        for (key, x_value, y_value) in (
            (combine(x_key, y_key), x_value, y_value)
            for (x_key, x_value) in cannonicalize(x)
            for (y_key, y_value) in cannonicalize(y)
        )
        if !isempty(key[1])
    )
end
function timedata_operation(f::Function, x::Map, y::Union{Number,TimeSeries,TimePattern})
    Map(x.indexes, [timedata_operation(f, val, y) for val in values(x)])
end
function timedata_operation(f::Function, x::Union{Number,TimeSeries,TimePattern}, y::Map)
    Map(y.indexes, [timedata_operation(f, x, val) for val in values(y)])
end
function timedata_operation(f::Function, x::Map, y::Map)
    x.indexes != y.indexes && error("`Map` indexes need to be indentical for `Map-Map` operations!")
    Map(
        x.indexes,
        [timedata_operation(f, valx, valy) for (valx, valy) in zip(values(x), values(y))]
    )
end

"""
    combine(x, y)

Combine given unions of intervals so e.g. M1-6;D1-5 combined with D3-7 results in M1-6;D3-5
"""
function combine(x::UnionOfIntersections, y::UnionOfIntersections)
    for z in (x, y)
        length(z) == 1 || error("can't combine union of multiple intersections $z")
    end
    unresolved_intersection = vcat(x[1], y[1])
    [resolve(unresolved_intersection)]
end

"""
    resolve(intersection)

Resolve the given intersection of intervals by turning something like D1-5;D3-7 into D3-5
"""
function resolve(unresolved::IntersectionOfIntervals)
    intervals_by_key = Dict()
    for interval in unresolved
        push!(get!(intervals_by_key, interval.key, []), interval)
    end
    TimeInterval[
        TimeInterval(key, lower, upper)
        for (key, lower, upper) in (
            (key, maximum(interval.lower for interval in intervals), minimum(interval.upper for interval in intervals))
            for (key, intervals) in intervals_by_key
        )
        if lower <= upper
    ]
end

"""
    cannonicalize!(time_pattern)

Modify a time-pattern in place so each key is a single range.
So something like {"M1-6,M9-12": 5} becomes {"M1-6": 5, "M9-12": 5}
"""
function cannonicalize!(time_pattern::TimePattern)
    for union_of_intersections in collect(keys(time_pattern))
        length(union_of_intersections) > 1 || continue
        value = pop!(time_pattern, union_of_intersections)
        for intersection in union_of_intersections
            time_pattern[[intersection]] = value
        end
    end
    time_pattern
end

"""
    cannonicalize(time_pattern)

A new time-pattern where each key is a single range.
So something like {"M1-6,M9-12": 5} becomes {"M1-6": 5, "M9-12": 5}
"""
cannonicalize(time_pattern::TimePattern) = cannonicalize!(copy(time_pattern))

_common_indexes(x::TimeSeries, y::TimeSeries) = sort!(unique!(vcat(x.indexes, y.indexes)))
_common_indexes(x::TimeSeries, y::TimePattern) = copy(x.indexes)
_common_indexes(x::TimePattern, y::TimeSeries) = copy(y.indexes)

"""
Generate indexes and values for a time series by applying f over arguments x and y.
"""
function _timedata_operation(f, x, y)
    indexes = _common_indexes(x, y)
    param_val_x = parameter_value(x)
    param_val_y = parameter_value(y)
    values = Any[(param_val_x(; t=t), param_val_y(; t=t)) for t in indexes]
    to_remove = findall(x -> isnan(x[1]) || isnan(x[2]), values)
    deleteat!(indexes, to_remove)
    deleteat!(values, to_remove)
    map!(x -> f(x...), values, values)
    indexes, values
end

function map_to_time_series(map::Map{K,V}, range=nothing) where {K,T<:TimeSeries,V<:Union{T,ParameterValue{T}}}
    inds = []
    vals = []
    for ts in _inner_value.(values(map))
        append!(inds, _get_range(ts.indexes, range))
        append!(vals, _get_range(ts.values, range))
    end
    TimeSeries(inds, vals, false, false)
end

_get_range(arr, range) = arr[range]
_get_range(arr, ::Nothing) = arr

_inner_value(x) = x
_inner_value(x::ParameterValue) = x.value