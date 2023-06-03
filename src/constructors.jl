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

Object(name::Symbol, class_name) = Object(name, class_name, [], [])
Object(name::AbstractString, args...) = Object(Symbol(name), args...)
Object(name::AbstractString, class_name::AbstractString, args...) = Object(Symbol(name), Symbol(class_name), args...)
Object(name::Symbol) = Object(name::Symbol, nothing)

"""
    TimeSlice(start::DateTime, end_::DateTime)

Construct a `TimeSlice` with bounds given by `start` and `end_`.
"""
function TimeSlice(start::DateTime, end_::DateTime, blocks::Object...; duration_unit=Hour)
    dur = Minute(end_ - start) / Minute(duration_unit(1))
    TimeSlice(start, end_, dur, blocks)
end

function TimeSeries(inds=[], vals=[]; ignore_year=false, repeat=false)
    TimeSeries(inds, vals, ignore_year, repeat)
end

Map(inds::Array{String,1}, vals::Array{V,1}) where {V} = Map(Symbol.(inds), vals)

Call(x) = Call(nothing, x)
Call(call_expr::Union{_CallExpr,Nothing}, x) = Call(call_expr, nothing, [x], NamedTuple())
Call(op::Function, args::Array) = Call(nothing, op, args, NamedTuple())
Call(op::T, x, y) where {T<:Function} = Call(op, [x, y])
Call(op::T, x::Call, y) where {T<:Function} = Call(_is_associative(T), op, x, y)
Call(op::T, x, y::Call) where {T<:Function} = Call(_is_associative(T), op, x, y)
Call(op::T, x::Call, y::Call) where {T<:Function} = Call(_is_associative(T), op, x, y)
Call(is_associative::Val{true}, op::Function, x::Call, y) = Call(op, [x.args; y])
Call(is_associative::Val{true}, op::Function, x, y::Call) = Call(op, [x; y.args])
Call(is_associative::Val{true}, op::Function, x::Call, y::Call) = Call(op, [x.args; y.args])
Call(is_associative::Val{false}, op::Function, x, y::Call) = Call(op, [x, y])
Call(is_associative::Val{false}, op::Function, x::Call, y) = Call(op, [x, y])
Call(is_associative::Val{false}, op::Function, x::Call, y::Call) = Call(op, [x, y])
function Call(call_expr::_CallExpr, func::T, kwargs::NamedTuple) where {T<:ParameterValue}
    Call(call_expr, func, [], kwargs)
end
Call(other::Call) = copy(other)

_is_associative(x) = Val(false)
_is_associative(::typeof(+)) = Val(true)
_is_associative(::typeof(*)) = Val(true)