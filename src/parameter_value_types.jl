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

# Special parameter value types
# types returned by the parsing function `spinedb_api.from_database`
# are automatically converted to these using `PyCall.pytype_mapping`.
# This allows us to mutiple dispatch `callable` below
struct DateTime_
    value::DateTime
end

abstract type DurationLike end

struct ScalarDuration <: DurationLike
    value::Period
end

struct ArrayDuration <: DurationLike
    value::Array{Period,1}
end

TimePattern = Dict{PeriodCollection,T} where T

struct TimeSeries{V}
    indexes::Array{DateTime,1}
    values::Array{V,1}
    ignore_year::Bool
    repeat::Bool
    function TimeSeries(inds, vals::Array{V,1}, iy, rep) where {V}
        if length(inds) != length(vals)
            error("lengths don't match")
        end
        new{V}(inds, vals, iy, rep)
    end
end

# Convert routines
# Here we specify how to go from `PyObject` returned by `spinedb_api.from_database` to our special type
Base.convert(::Type{DateTime_}, o::PyObject) = DateTime_(o.value)

# Helper function for `convert(::Type{DurationLike}, ::PyObject)`
function relativedelta_to_period(delta::PyObject)
    # Add up till the day level
    minutes = delta.minutes + 60 * (delta.hours + 24 * delta.days)
    if minutes > 0
        # No way the `relativedelta` implementation added beyond this point
        Minute(minutes)
    else
        months = delta.months + 12 * delta.years
        Month(months)
    end
end

function Base.convert(::Type{DurationLike}, o::PyObject)
    if length(o.value) == 1
        ScalarDuration(relativedelta_to_period(o.value[1]))
    else
        ArrayDuration([relativedelta_to_period(val) for val in o.value])
    end
end

function Base.convert(::Type{TimePattern}, o::PyObject)
    Dict(PeriodCollection(ind) => val for (ind, val) in zip(o.indexes, o.values))
end

function Base.convert(::Type{TimeSeries}, o::PyObject)
    ignore_year = o.ignore_year
    repeat = o.repeat
    values = o.values
    indexes = py"[s.astype(datetime) for s in $o.indexes]"
    ignore_year && (indexes = [s - Year(s) for s in indexes])
    TimeSeries(indexes, values, ignore_year, repeat)
end


# PyObject constructors
# TODO: specify PyObject constructor for other special types
function PyObject(ts::TimeSeries)
    @pycall db_api.TimeSeriesVariableResolution(ts.indexes, ts.values, ts.ignore_year, ts.repeat)::PyObject
end

# Base.append!
function Base.append!(ts::TimeSeries{T}, other::TimeSeries{T}) where T
    append!(ts.indexes, other.indexes)
    append!(ts.values, other.values)
    ts
end

# Base.copy
Base.copy(dur::ArrayDuration) = ArrayDuration(copy(dur.value))
Base.copy(tp::TimePattern) = TimePattern(Y=tp.Y, M=tp.M, D=tp.D, WD=tp.WD, h=tp.h, m=tp.m, s=tp.s)
Base.copy(ts::TimeSeries{T}) where T = TimeSeries(copy(ts.indexes), copy(ts.values), ts.ignore_year, ts.repeat)

# Callable types
# These are wrappers around standard Julia types and our special types above,
# that override the call operator
abstract type CallableLike end

struct NothingCallable <: CallableLike
end

struct ScalarCallable{T} <: CallableLike
    value::T
end

struct ArrayCallable{T,N} <: CallableLike
    value::Array{T,N}
end

struct TimePatternCallable{T} <: CallableLike
    value::TimePattern{T}
end

abstract type TimeSeriesCallableLike <: CallableLike end

struct TimeSeriesCallable{V} <: TimeSeriesCallableLike
    value::TimeSeries{V}
    t_map::TimeSliceMap
end

struct RepeatingTimeSeriesCallable{V} <: TimeSeriesCallableLike
    value::TimeSeries{V}
    span::Union{Period,Nothing}
    valsum::V
    len::Int64
    t_map::TimeSliceMap
end

# Required outer constructors
ScalarCallable(s::String) = ScalarCallable(Symbol(s))

function TimeSeriesCallableLike(ts::TimeSeries{V}) where {V}
    time_slices = [TimeSlice(t...) for t in zip(ts.indexes[1:end - 1], ts.indexes[2:end])]
    t_map = TimeSliceMap(time_slices)
    if ts.repeat
        span = ts.indexes[end] - ts.indexes[1]
        valsum = sum(ts.values)
        len = length(ts.values)
        RepeatingTimeSeriesCallable(ts, span, valsum, len, t_map)
    else
        TimeSeriesCallable(ts, t_map)
    end
end

# Call operator override
# Here we specify how to call our `...Callable` types
(p::NothingCallable)(;kwargs...) = nothing
(p::ScalarCallable)(;kwargs...) = p.value

function (p::ArrayCallable)(;i::Union{Int64,Nothing}=nothing, kwargs...)
    i === nothing && return p.value
    get(p.value, i, nothing)
end

# Helper functions for `(p::TimePatternCallable)()`
"""
    iscontained(ts::TimeSlice, pc::PeriodCollection)

Test whether a time slice is contained in a period collection.
"""
function iscontained(ts::TimeSlice, pc::PeriodCollection)
    fdict = Dict{Symbol,Function}(
        :Y => year,
        :M => month,
        :D => day,
        :WD => dayofweek,
        :h => hour,
        :m => minute,
        :s => second,
    )
    conds = Array{Bool,1}()
    sizehint!(conds, 7)
    for name in fieldnames(PeriodCollection)
        getfield(pc, name) == nothing && continue
        f = fdict[name]
        b = f(start(ts)):f(end_(ts))
        push!(conds, any(iscontained(b, a) for a in getfield(pc, name)))
    end
    all(conds)
end

iscontained(b::UnitRange{Int64}, a::UnitRange{Int64}) = b.start >= a.start && b.stop <= a.stop

function (p::TimePatternCallable)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
    t === nothing && return p.value
    values = [val for (tp, val) in p.value if iscontained(t, tp)]
    if isempty(values)
        nothing
    else
        mean(values)
    end
end

function (p::TimeSeriesCallable)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
    t === nothing && return p.value
    p.value.ignore_year && (t -= Year(start(t)))
    inds = map_indices(p.t_map, t)
    isempty(inds) && return nothing
    mean(p.value.values[first(inds):last(inds)])
end

function (p::RepeatingTimeSeriesCallable)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
    t === nothing && return p.value
    t_start = start(t)
    p.value.ignore_year && (t_start -= Year(t_start))
    if t_start > p.value.indexes[end]
        # Move t_start back within time_stamps range
        mismatch = t_start - p.value.indexes[1]
        reps = div(mismatch, p.span)
        t_start -= reps * p.span
    end
    t_end = t_start + (end_(t) - start(t))
    # Move t_end back within time_stamps range
    reps = if t_end > p.value.indexes[end]
        mismatch = t_end - p.value.indexes[1]
        div(mismatch, p.span)
    else
        0
    end
    t_end -= reps * p.span
    as = map_indices(p.t_map, t_start)
    bs = map_indices(p.t_map, t_end)
    if isempty(as) || isempty(bs)
        nothing
    else
        a = first(as)
        b = first(bs) - 1
        if a < b
            (sum(p.value.values[a:b-1]) + reps * p.valsum) / (b - a + reps * p.len)
        else
            div(
                sum(p.value.values[1:b]) + sum(p.value.values[a:end]) + (reps - 1) * p.valsum,
                b - a + 1 + reps * p.len
            )
        end
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
callable(parsed_value::ScalarDuration) = ScalarCallable(parsed_value.value)
callable(parsed_value::ArrayDuration) = ArrayCallable(parsed_value.value)
callable(parsed_value::TimePattern) = TimePatternCallable(parsed_value)
callable(parsed_value::TimeSeries) = TimeSeriesCallableLike(parsed_value)


# Iterate single ScalarCallable as collection
Base.iterate(v::ScalarCallable) = iterate((v,))
Base.iterate(v::ScalarCallable, state::T) where T = iterate((v,), state)
Base.length(v::ScalarCallable) = 1
# Compare ScalarCallable
Base.isless(v1::ScalarCallable, v2::ScalarCallable) = v1.value < v2.value
# Show ScalarCallable
Base.show(io::IO, v::ScalarCallable) = print(io, v.value)


Base.copy(c::NothingCallable) = c
Base.copy(c::ScalarCallable) = c
Base.copy(c::ArrayCallable) = ArrayCallable(copy(c.value))
Base.copy(c::TimePatternCallable) = TimePatternCallable(copy(c.value))
Base.copy(c::TimeSeriesCallable) = TimeSeriesCallable(copy(c.value), c.t_map)
Base.copy(c::RepeatingTimeSeriesCallable) = RepeatingTimeSeriesCallable(copy(c.value), c.span, c.valsum, c.len, c.t_map)