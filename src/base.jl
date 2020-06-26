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
Base.intersect(s::T, ::Anything) where T<:AbstractArray = s
Base.intersect(s::T, ::Anything) where T<:AbstractSet = s

Base.in(item, ::Anything) = true

Base.iterate(o::Object) = iterate((o,))
Base.iterate(o::Object, state::T) where T = iterate((o,), state)
Base.iterate(t::TimeSlice) = iterate((t,))
Base.iterate(t::TimeSlice, state::T) where T = iterate((t,), state)
Base.iterate(v::ScalarParameterValue) = iterate((v,))
Base.iterate(v::ScalarParameterValue, state::T) where T = iterate((v,), state)

Base.length(t::TimeSlice) = 1
Base.length(o::Object) = 1
Base.length(v::ScalarParameterValue) = 1

Base.isless(o1::Object, o2::Object) = o1.name < o2.name
Base.isless(a::TimeSlice, b::TimeSlice) = tuple(start(a), end_(a)) < tuple(start(b), end_(b))
Base.isless(v1::ScalarParameterValue, v2::ScalarParameterValue) = v1.value < v2.value

Base.:(==)(o1::Object, o2::Object) = o1.id == o2.id
Base.:(==)(a::TimeSlice, b::TimeSlice) = a.id == b.id

Base.hash(::Anything) = zero(UInt64)
Base.hash(o::Object) = o.id
Base.hash(t::TimeSlice) = t.id
Base.hash(r::RelationshipLike{K}) where {K} = hash(values(r))

Base.show(io::IO, ::Anything) = print(io, "anything")
Base.show(io::IO, o::Object) = print(io, o.name)
_dt_format = "yyyy-mm-ddTHH:MM"
Base.show(io::IO, t::TimeSlice) = 
    print(io, "$(Dates.format(start(t), _dt_format)) ~> $(Dates.format(end_(t), _dt_format))")
Base.show(io::IO, oc::ObjectClass) = print(io, oc.name)
Base.show(io::IO, rc::RelationshipClass) = print(io, rc.name)
Base.show(io::IO, p::Parameter) = print(io, p.name)
Base.show(io::IO, v::ScalarParameterValue) = print(io, v.value)
Base.show(io::IO, call::IdentityCall) = print(io, call.value)
Base.show(io::IO, call::OperatorCall) = print(io, join(call.args, string(" ", call.operator, " ")))
function Base.show(io::IO, call::ParameterCall)
    kwargs_str = join([join(kw, "=") for kw in pairs(call.kwargs)], ", ")
    print(io, string(call.parameter, "(", kwargs_str, ")"))
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
    print(io, join(ranges, ",\nand "))
end

Base.convert(::Type{DateTime_}, o::PyObject) = DateTime_(o.value)
Base.convert(::Type{Duration}, o::PyObject) = Duration(_relativedelta_to_period(o.value))
Base.convert(::Type{Array_}, o::PyObject) = Array_(o.values)
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
function Base.convert(::Type{Map}, o::PyObject)
    inds = py"[s for s in $o.indexes]"
    vals = o.values
    Map(inds, vals)
end
Base.convert(::Type{Call}, x::T) where {T<:Real} = IdentityCall(x)

Base.copy(tp::TimePattern) = TimePattern(Y=tp.Y, M=tp.M, D=tp.D, WD=tp.WD, h=tp.h, m=tp.m, s=tp.s)
Base.copy(ts::TimeSeries{T}) where T = TimeSeries(copy(ts.indexes), copy(ts.values), ts.ignore_year, ts.repeat)
Base.copy(c::NothingParameterValue) = c
Base.copy(c::ScalarParameterValue) = c
Base.copy(c::ArrayParameterValue) = ArrayParameterValue(copy(c.value))
Base.copy(c::TimePatternParameterValue) = TimePatternParameterValue(copy(c.value))
Base.copy(c::StandardTimeSeriesParameterValue) = StandardTimeSeriesParameterValue(copy(c.value), c.t_map)
function Base.copy(c::RepeatingTimeSeriesParameterValue)
	RepeatingTimeSeriesParameterValue(copy(c.value), c.span, c.valsum, c.len, c.t_map)
end
Base.copy(c::ParameterCall) = ParameterCall(c.parameter, c.kwargs)
Base.copy(c::OperatorCall) = OperatorCall(c.operator, c.args)
Base.copy(c::IdentityCall) = IdentityCall(c.value)

Base.zero(::Type{T}) where T<:Call = IdentityCall(0.0)
Base.zero(::Call) = IdentityCall(0.0)

Base.one(::Type{T}) where T<:Call = IdentityCall(1.0)
Base.one(::Call) = IdentityCall(1.0)

Base.:+(x::Call, y::Call) = OperatorCall(+, (x, y))
Base.:+(x::Call, y) = OperatorCall(+, (x, y))
Base.:+(x, y::Call) = OperatorCall(+, (x, y))
Base.:+(x::Call) = x
Base.:-(x::Call, y::Call) = OperatorCall(-, (x, y))
Base.:-(x::Call, y) = OperatorCall(-, (x, y))
Base.:-(x, y::Call) = OperatorCall(-, (x, y))
Base.:-(x::Call) = (-)(0.0, x)
Base.:*(x::Call, y::Call) = OperatorCall(*, (x, y))
Base.:*(x::Call, y) = OperatorCall(*, (x, y))
Base.:*(x, y::Call) = OperatorCall(*, (x, y))
Base.:/(x::Call, y::Call) = OperatorCall(/, (x, y))
Base.:/(x::Call, y) = OperatorCall(/, (x, y))
Base.:/(x, y::Call) = OperatorCall(/, (x, y))
Base.:+(t::TimeSlice, p::Period) = TimeSlice(start(t) + p, end_(t) + p, duration(t), blocks(t))
Base.:-(t::TimeSlice, p::Period) = (+)(t, -p)

Base.:min(x::Call, y::Call) = OperatorCall(min, (x, y))
Base.:min(x::Call, y) = OperatorCall(min, (x, y))
Base.:min(x, y::Call) = OperatorCall(min, (x, y))

# Override `getindex` for `Parameter` so we can call `parameter[...]` and get a `Call`
function Base.getindex(p::Parameter, inds::NamedTuple)
    parameter_value = _lookup_parameter_value(p; inds...)
    _call(p, inds, parameter_value)
end

# Patches: these just work-around `MethodError`s, but we should try something more consistent
Base.abs(call::IdentityCall) = IdentityCall(abs(realize(call)))