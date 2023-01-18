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

Base.intersect(::Anything, s) = s
Base.intersect(s::T, ::Anything) where {T<:AbstractArray} = s

Base.in(item, ::Anything) = true

Base.iterate(o::Union{Object,TimeSlice}) = iterate((o,))
Base.iterate(o::Union{Object,TimeSlice}, state::T) where {T} = iterate((o,), state)
Base.iterate(v::ScalarParameterValue) = iterate((v,))
Base.iterate(v::ScalarParameterValue, state::T) where {T} = iterate((v,), state)
function Base.iterate(x::Union{TimeSeries,Map}, state=1)
    if state > length(x)
        nothing
    else
        (x.indexes[state] => x.values[state]), state + 1
    end
end

Base.length(t::Union{Object,TimeSlice}) = 1
Base.length(v::ScalarParameterValue) = 1
Base.length(ts::Union{TimeSeries,Map}) = length(ts.indexes)

Base.isless(o1::Object, o2::Object) = o1.name < o2.name
Base.isless(a::TimeSlice, b::TimeSlice) = tuple(start(a), end_(a)) < tuple(start(b), end_(b))
Base.isless(v1::ScalarParameterValue, v2::ScalarParameterValue) = v1.value < v2.value
Base.isless(scalar::Number, ts::TimeSeries) = all(isless(scalar, v) for v in ts.values)
Base.isless(ts::TimeSeries, scalar::Number) = all(isless(v, scalar) for v in ts.values)
Base.isless(t::TimeSlice, dt::DateTime) = isless(end_(t), dt)
Base.isless(dt::DateTime, t::TimeSlice) = isless(dt, start(t))

Base.:(==)(o1::Object, o2::Object) = o1.id == o2.id
Base.:(==)(a::TimeSlice, b::TimeSlice) = a.id == b.id
Base.:(==)(ts1::TimeSeries, ts2::TimeSeries) = all(
    [getfield(ts1, field) == getfield(ts2, field) for field in fieldnames(TimeSeries)]
)
Base.:(==)(m1::Map, m2::Map) = all(m1.indexes == m2.indexes) && all(m1.values == m2.values)
Base.:(==)(pv1::AbstractParameterValue, pv2::AbstractParameterValue) = pv1.value == pv2.value
Base.:(==)(scalar::Number, ts::TimeSeries) = all(scalar == v for v in ts.values)
Base.:(==)(ts::TimeSeries, scalar::Number) = all(v == scalar for v in ts.values)
function Base.:(==)(x::Call, y::Call)
    result = all(getproperty(x, n) == getproperty(y, n) for n in setdiff(fieldnames(Call), (:args,)))
    result &= tuple(x.args...) == tuple(y.args...)
end

Base.:(<=)(scalar::Number, ts::TimeSeries) = all(scalar <= v for v in ts.values)
Base.:(<=)(ts::TimeSeries, scalar::Number) = all(v <= scalar for v in ts.values)
Base.:(<=)(t::TimeSlice, dt::DateTime) = end_(t) <= dt

Base.hash(::Anything) = zero(UInt64)
Base.hash(o::Union{Object,TimeSlice}) = o.id
Base.hash(r::RelationshipLike{K}) where {K} = hash(values(r))

Base.show(io::IO, ::Anything) = print(io, "anything")
Base.show(io::IO, o::Object) = print(io, o.name)
Base.show(io::IO, t::TimeSlice) = print(io, string(Dates.format(start(t), _df)), "~>", Dates.format(end_(t), _df))
Base.show(io::IO, s::_StartRef) = print(io, string(Dates.format(start(s.time_slice), _df)))
Base.show(io::IO, oc::ObjectClass) = print(io, oc.name)
Base.show(io::IO, rc::RelationshipClass) = print(io, rc.name)
Base.show(io::IO, p::Parameter) = print(io, p.name)
Base.show(io::IO, v::ScalarParameterValue) = print(io, v.value)
Base.show(io::IO, call::Call) = _show_call(io, call, call.call_expr, call.func)
function Base.show(io::IO, union::UnionOfIntersections)
    d = Dict{Symbol,String}(
        :Y => "year",
        :M => "month",
        :D => "day",
        :WD => "day of the week",
        :h => "hour",
        :m => "minute",
        :s => "second",
    )
    intersections = [
        join(["$(d[i.key]) from $(i.lower) to $(i.upper)" for i in intersection], ", and ")
        for intersection in union
    ]
    print(io, join(intersections, ", or "))
end
function Base.show(io::IO, ts::TimeSeries{T}) where T <: Number
    first_ = first(ts.indexes)
    last_ = last(ts.indexes)
    min_ = minimum(ts.values)
    max_ = maximum(ts.values)
    print(io, "TimeSeries{$first_~>$last_}[$min_,$max_]($(ts.ignore_year),$(ts.repeat))")
end
function Base.show(io::IO, ts::TimeSeries)
    first_ = string(first(ts.indexes), "=>", first(ts.values))
    last_ = string(last(ts.indexes), "=>", last(ts.values))
    print(io, "TimeSeries{$first_ ... $last_}, ($(ts.ignore_year), $(ts.repeat))")
end

Base.convert(::Type{Call}, x::T) where {T<:Real} = Call(x)

Base.copy(ts::TimeSeries{T}) where {T} = TimeSeries(copy(ts.indexes), copy(ts.values), ts.ignore_year, ts.repeat)
Base.copy(c::NothingParameterValue) = c
Base.copy(c::ScalarParameterValue) = c
Base.copy(c::ArrayParameterValue) = ArrayParameterValue(copy(c.value))
Base.copy(c::TimePatternParameterValue) = TimePatternParameterValue(copy(c.value))
Base.copy(c::StandardTimeSeriesParameterValue) = StandardTimeSeriesParameterValue(copy(c.value))
function Base.copy(c::RepeatingTimeSeriesParameterValue)
    RepeatingTimeSeriesParameterValue(copy(c.value), c.span, c.valsum, c.len)
end
Base.copy(c::Call) = Call(c.call_expr, c.func, c.args, c.kwargs)

Base.zero(::Type{T}) where {T<:Call} = Call(zero(Float64))
Base.zero(::Call) = Call(zero(Float64))

Base.one(::Type{T}) where {T<:Call} = Call(one(Float64))
Base.one(::Call) = Call(one(Float64))

Base.:+(x::Call, y::Call) = Call(+, x, y)
Base.:+(x::Call, y) = Call(+, x, y)
Base.:+(x, y::Call) = Call(+, x, y)
Base.:+(x::Call) = x
Base.:+(ts::TimeSeries) = +(0.0, ts)
Base.:+(ts::TimeSeries, num::Number) = timedata_operation(+, ts, num)
Base.:+(num::Number, ts::TimeSeries) = timedata_operation(+, num, ts)
Base.:+(tp::TimePattern, num::Number) = timedata_operation(+, tp, num)
Base.:+(num::Number, tp::TimePattern) = timedata_operation(+, num, tp)
Base.:+(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(+, ts1, ts2)
Base.:+(ts::TimeSeries, tp::TimePattern) = timedata_operation(+, ts, tp)
Base.:+(tp::TimePattern, ts::TimeSeries) = timedata_operation(+, tp, ts)
Base.:+(tp1::TimePattern, tp2::TimePattern) = timedata_operation(+, tp1, tp2)
Base.:-(x::Call, y::Call) = Call(+, x, -y)
Base.:-(x::Call, y) = Call(+, x, -y)
Base.:-(x, y::Call) = Call(+, x, -y)
Base.:-(x::Call) = Call(-, zero(Call), x)
Base.:-(ts::TimeSeries) = -(0.0, ts)
Base.:-(ts::TimeSeries, num::Number) = timedata_operation(-, ts, num)
Base.:-(num::Number, ts::TimeSeries) = timedata_operation(-, num, ts)
Base.:-(tp::TimePattern, num::Number) = timedata_operation(-, tp, num)
Base.:-(num::Number, tp::TimePattern) = timedata_operation(-, num, tp)
Base.:-(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(-, ts1, ts2)
Base.:-(ts::TimeSeries, tp::TimePattern) = timedata_operation(-, ts, tp)
Base.:-(tp::TimePattern, ts::TimeSeries) = timedata_operation(-, tp, ts)
Base.:-(tp1::TimePattern, tp2::TimePattern) = timedata_operation(-, tp1, tp2)
Base.:*(x::Call, y::Call) = Call(*, x, y)
Base.:*(x::Call, y) = Call(*, x, y)
Base.:*(x, y::Call) = Call(*, x, y)
Base.:*(ts::TimeSeries, num::Number) = timedata_operation(*, ts, num)
Base.:*(num::Number, ts::TimeSeries) = timedata_operation(*, num, ts)
Base.:*(tp::TimePattern, num::Number) = timedata_operation(*, tp, num)
Base.:*(num::Number, tp::TimePattern) = timedata_operation(*, num, tp)
Base.:*(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(*, ts1, ts2)
Base.:*(ts::TimeSeries, tp::TimePattern) = timedata_operation(*, ts, tp)
Base.:*(tp::TimePattern, ts::TimeSeries) = timedata_operation(*, tp, ts)
Base.:*(tp1::TimePattern, tp2::TimePattern) = timedata_operation(*, tp1, tp2)
Base.:/(x::Call, y::Call) = Call(/, x, y)
Base.:/(x::Call, y) = Call(/, x, y)
Base.:/(x, y::Call) = Call(/, x, y)
Base.:/(ts::TimeSeries, num::Number) = timedata_operation(/, ts, num)
Base.:/(num::Number, ts::TimeSeries) = timedata_operation(/, num, ts)
Base.:/(tp::TimePattern, num::Number) = timedata_operation(/, tp, num)
Base.:/(num::Number, tp::TimePattern) = timedata_operation(/, num, tp)
Base.:/(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(/, ts1, ts2)
Base.:/(ts::TimeSeries, tp::TimePattern) = timedata_operation(/, ts, tp)
Base.:/(tp::TimePattern, ts::TimeSeries) = timedata_operation(/, tp, ts)
Base.:/(tp1::TimePattern, tp2::TimePattern) = timedata_operation(/, tp1, tp2)
Base.:+(t::TimeSlice, p::Period) = TimeSlice(start(t) + p, start(t) + p + (end_(t) - start(t)), duration(t), blocks(t))
Base.:-(t::TimeSlice, p::Period) = (+)(t, -p)
Base.:^(ts::TimeSeries, num::Number) = timedata_operation(^, ts, num)
Base.:^(num::Number, ts::TimeSeries) = timedata_operation(^, num, ts)
Base.:^(tp::TimePattern, num::Number) = timedata_operation(^, tp, num)
Base.:^(num::Number, tp::TimePattern) = timedata_operation(^, num, tp)
Base.:^(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(^, ts1, ts2)
Base.:^(ts::TimeSeries, tp::TimePattern) = timedata_operation(^, ts, tp)
Base.:^(tp::TimePattern, ts::TimeSeries) = timedata_operation(^, tp, ts)
Base.:^(tp1::TimePattern, tp2::TimePattern) = timedata_operation(^, tp1, tp2)

Base.:min(x::Call, y::Call) = Call(min, x, y)
Base.:min(x::Call, y) = Call(min, x, y)
Base.:min(x, y::Call) = Call(min, x, y)

Base.values(ts::TimeSeries) = ts.values
Base.values(m::Map) = m.values
Base.values(apv::AbstractParameterValue) = values(apv.value)

Base.keys(ts::TimeSeries) = ts.indexes
Base.keys(m::Map) = m.indexes
Base.keys(apv::AbstractParameterValue) = keys(apv.value)

# Override `getindex` for `Parameter` so we can call `parameter[...]` and get a `Call`
function Base.getindex(p::Parameter, inds::NamedTuple)
    pv_new_kwargs = _split_parameter_value_kwargs(p; inds...)
    if pv_new_kwargs !== nothing
        parameter_value, new_inds = pv_new_kwargs
        _pv_call((p.name, inds), parameter_value, new_inds)
    else
        nothing
    end
end

function Base.push!(ts::TimeSeries, pair)
    index, value = pair
    i = searchsortedfirst(ts.indexes, index)
    if get(ts.indexes, i, nothing) == index
        ts.values[i] = value
    else
        insert!(ts.indexes, i, index)
        insert!(ts.values, i, value)
    end
    ts._lookup[index] = value
    ts
end

function Base.setindex!(ts::TimeSeries, value, key...)
    length(key) > 1 && error("invalid index $key")
    push!(ts, first(key) => value)
    value
end

function Base.empty!(x::ObjectClass)
    empty!(x.objects)
    empty!(x.parameter_values)
    empty!(x.parameter_defaults)
end
function Base.empty!(x::RelationshipClass)
    empty!(x.intact_object_class_names)
    empty!(x.object_class_names)
    empty!(x.relationships)
    empty!(x.parameter_values)
    empty!(x.parameter_defaults)
    empty!(x.lookup_cache)
end
function Base.empty!(x::Parameter)
    empty!(x.classes)
end

function Base.merge!(ts1::TimeSeries, ts2::TimeSeries)
    for (index, value) in ts2
        ts1[index] = value
    end
    ts1
end

Base.get(x::Map, key, default) = get(x._lookup, key, default)
Base.get(x::TimeSeries, key, default) = get(x._lookup, key, default)

Base.iszero(x::Union{TimeSeries,TimePattern}) = iszero(values(x))
Base.isapprox(x::Union{TimeSeries,TimePattern}, y; kwargs...) = all(isapprox(v, y; kwargs...) for v in values(x))
Base.isapprox(x::AbstractParameterValue, y; kwargs...) = isapprox(x(), y; kwargs...)

# Patches: these just work-around `MethodError`s, but we should try something more consistent
Base.abs(call::Call) = Call(abs, [call])
