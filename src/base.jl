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

Base.length(t::Union{Object,TimeSlice}) = 1
Base.length(v::ScalarParameterValue) = 1

Base.isless(o1::Object, o2::Object) = o1.name < o2.name
Base.isless(a::TimeSlice, b::TimeSlice) = tuple(start(a), end_(a)) < tuple(start(b), end_(b))
Base.isless(v1::ScalarParameterValue, v2::ScalarParameterValue) = v1.value < v2.value

Base.:(==)(o1::Object, o2::Object) = o1.id == o2.id
Base.:(==)(a::TimeSlice, b::TimeSlice) = a.id == b.id
Base.:(==)(ts1::TimeSeries, ts2::TimeSeries) = all([getfield(ts1, field) == getfield(ts2, field) for field in fieldnames(TimeSeries)])

Base.hash(::Anything) = zero(UInt64)
Base.hash(o::Union{Object,TimeSlice}) = o.id
Base.hash(r::RelationshipLike{K}) where {K} = hash(values(r))

Base.show(io::IO, ::Anything) = print(io, "anything")
Base.show(io::IO, o::Object) = print(io, o.name)
Base.show(io::IO, t::TimeSlice) = print(io, string(Dates.format(start(t), _df)), "~>", Dates.format(end_(t), _df))
Base.show(io::IO, d::_DateTimeRef) = print(io, string(Dates.format(d.ref[], _df)))
Base.show(io::IO, oc::ObjectClass) = print(io, oc.name)
Base.show(io::IO, rc::RelationshipClass) = print(io, rc.name)
Base.show(io::IO, p::Parameter) = print(io, p.name)
Base.show(io::IO, v::ScalarParameterValue) = print(io, v.value)
Base.show(io::IO, call::OperatorCall) = print(io, join(call.args, string(" ", call.operator, " ")))
Base.show(io::IO, call::IdentityCall{Nothing,T}) where {T} = print(io, realize(call))
function Base.show(io::IO, call::Union{IdentityCall,ParameterValueCall})
    pname, kwargs = call.original_call
    kwargs_str = join((join(kw, "=") for kw in pairs(kwargs)), ", ")
    result = realize(call)
    print(io, string("{", pname, "(", kwargs_str, ") = ", result, "}"))
end
function Base.show(io::IO, period_collection::PeriodCollection)
    d = Dict{Symbol,String}(
        :Y => "year",
        :M => "month",
        :D => "day",
        :WD => "day of the week",
        :h => "hour",
        :m => "minute",
        :s => "second",
    )
    ranges = Array{String,1}()
    for field in fieldnames(PeriodCollection)
        value = getfield(period_collection, field)
        if value != nothing
            str = "$(d[field]) from "
            str *= join(["$(x.start) to $(x.stop)" for x in value], ", or ")
            push!(ranges, str)
        end
    end
    print(io, join(ranges, ", and "))
end

Base.convert(::Type{Call}, x::T) where {T<:Real} = IdentityCall(x)

Base.copy(ts::TimeSeries{T}) where {T} = TimeSeries(copy(ts.indexes), copy(ts.values), ts.ignore_year, ts.repeat)
Base.copy(c::NothingParameterValue) = c
Base.copy(c::ScalarParameterValue) = c
Base.copy(c::ArrayParameterValue) = ArrayParameterValue(copy(c.value))
Base.copy(c::TimePatternParameterValue) = TimePatternParameterValue(copy(c.value))
Base.copy(c::StandardTimeSeriesParameterValue) = StandardTimeSeriesParameterValue(copy(c.value))
function Base.copy(c::RepeatingTimeSeriesParameterValue)
    RepeatingTimeSeriesParameterValue(copy(c.value), c.span, c.valsum, c.len)
end
Base.copy(c::ParameterValueCall) = ParameterValueCall(c.original_call, c.parameter_value, c.kwargs)
Base.copy(c::OperatorCall) = OperatorCall(c.operator, c.args)
Base.copy(c::IdentityCall) = IdentityCall(c.original_call, c.value)

Base.zero(::Type{T}) where {T<:Call} = IdentityCall(0.0)
Base.zero(::Call) = IdentityCall(0.0)

Base.one(::Type{T}) where {T<:Call} = IdentityCall(1.0)
Base.one(::Call) = IdentityCall(1.0)

Base.:+(x::Call, y::Call) = OperatorCall(+, x, y)
Base.:+(x::Call, y) = OperatorCall(+, x, y)
Base.:+(x, y::Call) = OperatorCall(+, x, y)
Base.:+(x::Call) = x
Base.:+(ts::TimeSeries, num::Number) = timedata_operation(+, ts, num)
Base.:+(num::Number, ts::TimeSeries) = timedata_operation(+, num, ts)
Base.:+(tp::TimePattern, num::Number) = timedata_operation(+, tp, num)
Base.:+(num::Number, tp::TimePattern) = timedata_operation(+, num, tp)
Base.:+(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(+, ts1, ts2)
Base.:+(ts::TimeSeries, tp::TimePattern) = timedata_operation(+, ts, tp)
Base.:+(tp::TimePattern, ts::TimeSeries) = timedata_operation(+, tp, ts)
Base.:-(x::Call, y::Call) = OperatorCall(+, x, -y)
Base.:-(x::Call, y) = OperatorCall(+, x, -y)
Base.:-(x, y::Call) = OperatorCall(+, x, -y)
Base.:-(x::Call) = OperatorCall(-, zero(Call), x)
Base.:-(ts::TimeSeries, num::Number) = timedata_operation(-, ts, num)
Base.:-(num::Number, ts::TimeSeries) = timedata_operation(-, num, ts)
Base.:-(tp::TimePattern, num::Number) = timedata_operation(-, tp, num)
Base.:-(num::Number, tp::TimePattern) = timedata_operation(-, num, tp)
Base.:-(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(-, ts1, ts2)
Base.:-(ts::TimeSeries, tp::TimePattern) = timedata_operation(-, ts, tp)
Base.:-(tp::TimePattern, ts::TimeSeries) = timedata_operation(-, tp, ts)
Base.:*(x::Call, y::Call) = OperatorCall(*, x, y)
Base.:*(x::Call, y) = OperatorCall(*, x, y)
Base.:*(x, y::Call) = OperatorCall(*, x, y)
Base.:*(ts::TimeSeries, num::Number) = timedata_operation(*, ts, num)
Base.:*(num::Number, ts::TimeSeries) = timedata_operation(*, num, ts)
Base.:*(tp::TimePattern, num::Number) = timedata_operation(*, tp, num)
Base.:*(num::Number, tp::TimePattern) = timedata_operation(*, num, tp)
Base.:*(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(*, ts1, ts2)
Base.:*(ts::TimeSeries, tp::TimePattern) = timedata_operation(*, ts, tp)
Base.:*(tp::TimePattern, ts::TimeSeries) = timedata_operation(*, tp, ts)
Base.:/(x::Call, y::Call) = OperatorCall(/, x, y)
Base.:/(x::Call, y) = OperatorCall(/, x, y)
Base.:/(x, y::Call) = OperatorCall(/, x, y)
Base.:/(ts::TimeSeries, num::Number) = timedata_operation(/, ts, num)
Base.:/(num::Number, ts::TimeSeries) = timedata_operation(/, num, ts)
Base.:/(tp::TimePattern, num::Number) = timedata_operation(/, tp, num)
Base.:/(num::Number, tp::TimePattern) = timedata_operation(/, num, tp)
Base.:/(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(/, ts1, ts2)
Base.:/(ts::TimeSeries, tp::TimePattern) = timedata_operation(/, ts, tp)
Base.:/(tp::TimePattern, ts::TimeSeries) = timedata_operation(/, tp, ts)
Base.:+(t::TimeSlice, p::Period) = TimeSlice(start(t) + p, end_(t) + p, duration(t), blocks(t))
Base.:-(t::TimeSlice, p::Period) = (+)(t, -p)
Base.:^(ts::TimeSeries, num::Number) = timedata_operation(^, ts, num)
Base.:^(num::Number, ts::TimeSeries) = timedata_operation(^, num, ts)
Base.:^(tp::TimePattern, num::Number) = timedata_operation(^, tp, num)
Base.:^(num::Number, tp::TimePattern) = timedata_operation(^, num, tp)
Base.:^(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(^, ts1, ts2)
Base.:^(ts::TimeSeries, tp::TimePattern) = timedata_operation(^, ts, tp)
Base.:^(tp::TimePattern, ts::TimeSeries) = timedata_operation(^, tp, ts)

Base.:min(x::Call, y::Call) = OperatorCall(min, x, y)
Base.:min(x::Call, y) = OperatorCall(min, x, y)
Base.:min(x, y::Call) = OperatorCall(min, x, y)

# Override `getindex` for `Parameter` so we can call `parameter[...]` and get a `Call`
function Base.getindex(p::Parameter, inds::NamedTuple)
    pv_new_kwargs = _lookup_parameter_value(p; inds...)
    if pv_new_kwargs !== nothing
        parameter_value, new_inds = pv_new_kwargs
        _pv_call((p.name, inds), parameter_value, new_inds)
    else
        nothing
    end
end

# Patches: these just work-around `MethodError`s, but we should try something more consistent
Base.abs(call::IdentityCall) = IdentityCall(abs(realize(call)))
