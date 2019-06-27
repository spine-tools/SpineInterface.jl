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

# Special types
# types returned by `spinedb_api.from_database` are automatically converted to these
# using `PyCall.pytype_mapping` system.
# This allows us to mutiple dispatch `callable` below
struct DateTime_
    value::DateTime
end

struct Duration
    value::Period
end

struct TimeSeries{I,V}
    indexes::I
    values::Array{V,1}
    ignore_year::Bool
    repeat::Bool
end

# Convert routines
# Here we specify how to go from `PyObject` returned by `spinedb_api.from_database` to our special type
Base.convert(::Type{DateTime_}, o::PyObject) = DateTime_(o.value)
Base.convert(::Type{Duration}, o::PyObject) = Duration(relativedelta_to_period(o.value)) # TODO: variable duration?

function Base.convert(::Type{TimeSeries}, o::PyObject)
    ignore_year = o.ignore_year
    repeat = o.repeat
    values = o.values
    if pyisinstance(o, db_api.TimeSeriesFixedResolution) && length(o.resolution) == 1
        # Let's use StepRange here for efficiency since we can
        start = o.start
        len = length(values)
        res = relativedelta_to_period(o.resolution[1])
        end_ = start + len * res
        indexes = start:res:end_
    else
        indexes = py"[s.astype(datetime) for s in $o.indexes]"
    end
    TimeSeries(indexes, values, ignore_year, repeat)
end

function relativedelta_to_period(delta::PyObject)
    if delta.minutes > 0
        Minute(delta.minutes)
    elseif delta.hours > 0
        Hour(delta.hours)
    elseif delta.days > 0
        Day(delta.days)
    elseif delta.months > 0
        Month(delta.months)
    elseif delta.years > 0
        Year(delta.years)
    else
        Minute(0)
    end
end

# Callable types
# These are wrappers around standard Julia types and our special types above
# that override the call operator
struct NothingCallable
end

struct ScalarCallable{T}
    value::T
end

struct ArrayCallable{T,N}
    value::Array{T,N}
end

struct TimePatternCallable{T}
    dict::Dict{TimePattern,T}
    default
end

abstract type TimeSeriesCallableLike end

struct TimeSeriesCallable{I,V} <: TimeSeriesCallableLike
    value::TimeSeries{I,V}
end

struct RepeatingTimeSeriesCallable{I,V,MV} <: TimeSeriesCallableLike
    value::TimeSeries{I,V}
    span::Union{Period,Nothing}
    mean_value::MV
end


# Constructors
ScalarCallable(s::String) = ScalarCallable(Symbol(s))

function TimeSeriesCallableLike(ts::TimeSeries{I,V}) where {I,V}
    if ts.repeat
        span = ts.indexes[end] - ts.indexes[1]
        mean_value = mean(ts.values)
        RepeatingTimeSeriesCallable(ts, span, mean_value)
    else
        TimeSeriesCallable(ts)
    end
end

# Call operators
(p::NothingCallable)(;kwargs...) = nothing
(p::ScalarCallable)(;kwargs...) = p.value

function (p::ArrayCallable)(;i::Union{Int64,Nothing}=nothing)
    if i === nothing
        @warn("argument `i` missing, returning the whole array")
        p.value
    else
        p.value[i]
    end
end

"""
    match(ts::TimeSlice, tp::TimePattern)

Test whether a time slice matches a time pattern.
A time pattern and a time series match iff, for every time level (year, month, and so on),
the time slice fully contains at least one of the ranges specified in the time pattern for that level.
"""
function match(ts::TimeSlice, tp::TimePattern)
    conds = Array{Bool,1}()
    tp.y != nothing && push!(conds, any(range_in(rng, year(ts.start):year(ts.end_)) for rng in tp.y))
    tp.m != nothing && push!(conds, any(range_in(rng, month(ts.start):month(ts.end_)) for rng in tp.m))
    tp.d != nothing && push!(conds, any(range_in(rng, day(ts.start):day(ts.end_)) for rng in tp.d))
    tp.wd != nothing && push!(conds, any(range_in(rng, dayofweek(ts.start):dayofweek(ts.end_)) for rng in tp.wd))
    tp.H != nothing && push!(conds, any(range_in(rng, hour(ts.start):hour(ts.end_)) for rng in tp.H))
    tp.M != nothing && push!(conds, any(range_in(rng, minute(ts.start):minute(ts.end_)) for rng in tp.M))
    tp.S != nothing && push!(conds, any(range_in(rng, second(ts.start):second(ts.end_)) for rng in tp.S))
    all(conds)
end

"""
    range_in(b::UnitRange{Int64}, a::UnitRange{Int64})

Test whether `b` is fully contained in `a`.
"""
range_in(b::UnitRange{Int64}, a::UnitRange{Int64}) = b.start >= a.start && b.stop <= a.stop

function (p::TimePatternCallable)(;t::Union{TimeSlice,Nothing}=nothing)
    t === nothing && error("argument `t` missing")
    values = [val for (tp, val) in p.dict if match(t, tp)]
    if isempty(values)
        @warn("$t does not match $p, using default value...")
        p.default
    else
        mean(values)
    end
end

function (p::TimeSeriesCallable)(;t::Union{TimeSlice,Nothing}=nothing)
    t === nothing && return p.value
    t_start = t.start
    t_end = t.end_
    t_duration = t.duration
    if p.value.ignore_year
        t_start -= Year(t_start)
        t_end = t_start + t_duration
    end
    a = findfirst(i -> i >= t_start, p.value.indexes)
    b = findlast(i -> i <= t_end, p.value.indexes)
    if a === nothing || b === nothing
        error("$p is not defined on $t")
    else
        mean(p.value.values[a:b])
    end
end

function (p::RepeatingTimeSeriesCallable)(;t::Union{TimeSlice,Nothing}=nothing)
    t === nothing && return p.value
    t_start = t.start
    t_end = t.end_
    t_duration = t.duration
    if p.value.ignore_year
        t_start -= Year(t_start)
        t_end = t_start + t_duration
    end
    repetitions = 0
    if t_start > p.value.indexes[end]
        # Move start back within time_stamps range
        mismatch = start - p.value.indexes[1]
        repetitions = div(mismatch, p.span)
        t_start -= repetitions * p.span
        t_end = start + duration
    end
    if t_end > p.value.indexes[end]
        # Move end_ back within time_stamps range
        mismatch = t_end - p.value.indexes[1]
        repetitions = div(mismatch, p.span)
        t_end -= repetitions * p.span
    end
    a = findfirst(i -> i >= t_start, p.value.indexes)
    b = findlast(i -> i < t_end, p.value.indexes)
    if a === nothing || b === nothing
        error("$p is not defined on $t")
    else
        if a <= b
            value = mean(p.value.values[a:b])
        else
            value = -mean(p.value.values[b:a])
        end
        value + repetitions * p.mean_value  # repetitions holds the number of rolls we move back the end
    end
end

# Create callable from value parsed from database
callable(parsed_value::Nothing) = NothingCallable()
callable(parsed_value::Bool) = ScalarCallable(parsed_value)
callable(parsed_value::Int64) = ScalarCallable(parsed_value)
callable(parsed_value::Float64) = ScalarCallable(parsed_value)
callable(parsed_value::String) = ScalarCallable(parsed_value)
callable(parsed_value::Array) = ArrayCallable(parsed_value)
callable(parsed_value::DateTime_) = ScalarCallable(parsed_value.value)
callable(parsed_value::Duration) = ScalarCallable(parsed_value.value)
callable(parsed_value::TimePattern) = TimePatternCallable(parsed_value)
callable(parsed_value::TimeSeries) = TimeSeriesCallableLike(parsed_value)


# Utility
"""
    time_stamps(val::TimeSeriesCallable)
"""
time_stamps(val::TimeSeriesCallable) = val.indexes

# Iterate single ScalarCallable as collection
Base.iterate(v::ScalarCallable) = iterate((v,))
Base.iterate(v::ScalarCallable, state::T) where T = iterate((v,), state)
Base.length(v::ScalarCallable) = 1
# Compare ScalarCallable
Base.isless(v1::ScalarCallable, v2::ScalarCallable) = v1.value < v2.value
# Show ScalarCallable
Base.show(io::IO, v::ScalarCallable) = print(io, v.value)
