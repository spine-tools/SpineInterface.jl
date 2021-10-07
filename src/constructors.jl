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

Object(name::Symbol, id) = Object(name, id, [], [])
Object(name::AbstractString, args...) = Object(Symbol(name), args...)
Object(name::Symbol) = Base.invokelatest(Object, name)  # NOTE: this allows us to override `Object` in `using_spinedb`

"""
    TimeSlice(start::DateTime, end_::DateTime)

Construct a `TimeSlice` with bounds given by `start` and `end_`.
"""
function TimeSlice(start::DateTime, end_::DateTime, blocks::Object...; duration_unit=Hour)
    dur = Minute(end_ - start) / Minute(duration_unit(1))
    TimeSlice(start, end_, dur, blocks)
end

Map(inds::Array{String,1}, vals::Array{V,1}) where {V} = Map(Symbol.(inds), vals)

ScalarParameterValue(s::String) = ScalarParameterValue(Symbol(s))

function TimeSeriesParameterValue(ts::TimeSeries{V}) where {V}
    if ts.repeat
        span = ts.indexes[end] - ts.indexes[1]
        valsum = sum(Iterators.filter(!isnan, ts.values))
        len = count(!isnan, ts.values)
        RepeatingTimeSeriesParameterValue(ts, span, valsum, len)
    else
        StandardTimeSeriesParameterValue(ts)
    end
end

Call(other::Call) = copy(other)
Call(n) = IdentityCall(n)

IdentityCall(x) = IdentityCall(nothing, x)

OperatorCall(op::Function, x, y) = OperatorCall(op, [x, y])
function OperatorCall(op::Function, x::OperatorCall{T}, y::OperatorCall{S}) where {T<:Function,S<:Function}
    OperatorCall(op, [x, y])
end
OperatorCall(op::T, x::OperatorCall{T}, y) where {T<:Function} = OperatorCall(_is_associative(T), op, x, y)
OperatorCall(op::T, x, y::OperatorCall{T}) where {T<:Function} = OperatorCall(_is_associative(T), op, x, y)
function OperatorCall(op::T, x::OperatorCall{T}, y::OperatorCall{T}) where {T<:Function}
    OperatorCall(_is_associative(T), op, x, y)
end

OperatorCall(is_associative::Val{true}, op::T, x::OperatorCall{T}, y) where {T<:Function} =
    OperatorCall(op, [x.args; y])
OperatorCall(is_associative::Val{true}, op::T, x, y::OperatorCall{T}) where {T<:Function} =
    OperatorCall(op, [x; y.args])
function OperatorCall(is_associative::Val{true}, op::T, x::OperatorCall{T}, y::OperatorCall{T}) where {T<:Function}
    OperatorCall(op, [x.args; y.args])
end
OperatorCall(is_associative::Val{false}, op::T, x, y::OperatorCall{T}) where {T<:Function} = OperatorCall(op, [x, y])
OperatorCall(is_associative::Val{false}, op::T, x::OperatorCall{T}, y) where {T<:Function} = OperatorCall(op, [x, y])
function OperatorCall(is_associative::Val{false}, op::T, x::OperatorCall{T}, y::OperatorCall{T}) where {T<:Function}
    OperatorCall(op, [x, y])
end
