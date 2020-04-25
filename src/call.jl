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

# Outer constructors
Call(n) = IdentityCall(n)
Call(op::Function, args::Tuple) = OperatorCall(op, args)
Call(param::Parameter, kwargs::NamedTuple) = ParameterCall(param, kwargs)
Call(other::Call) = copy(other)

# api
"""
    realize(x::Call)

Perform the given `Call` and return the result.
"""
realize(x) = x
realize(call::IdentityCall) = call.value
realize(call::OperatorCall) = call.operator(realize.(call.args)...)
realize(call::ParameterCall) = call.parameter(; call.kwargs...)

"""
    is_varying(x::Call)

Whether or not the given `Call` might return a different result if realized a second time.
This is true for `ParameterCall`s which are sensitive to the `t` argument.
"""
is_varying(x) = false
is_varying(call::OperatorCall) = any(is_varying(arg) for arg in call.args)
is_varying(call::ParameterCall) = true

# Base
Base.copy(c::ParameterCall) = ParameterCall(c.parameter, c.kwargs)
Base.copy(c::OperatorCall) = OperatorCall(c.operator, c.args)
Base.copy(c::IdentityCall) = IdentityCall(c.value)
Base.convert(::Type{Call}, x::T) where {T<:Real} = IdentityCall(x)
Base.show(io::IO, call::IdentityCall) = print(io, call.value)
Base.show(io::IO, call::OperatorCall) = print(io, join(call.args, string(" ", call.operator, " ")))
function Base.show(io::IO, call::ParameterCall)
    kwargs_str = join([join(kw, "=") for kw in pairs(call.kwargs)], ", ")
    print(io, string(call.parameter, "(", kwargs_str, ")"))
end

# operators
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

# Override `getindex` for `Parameter` so we can call `parameter[...]` and get a `Call`
function Base.getindex(p::Parameter, inds::NamedTuple)
    callable = _lookup_callable(p; inds...)
    if callable isa AbstractTimeSeriesCallable || callable isa TimePatternCallable
        ParameterCall(p, inds)
    else
        IdentityCall(p(; inds...))
    end
end

# Patches: these just work-around `MethodError`s, but we should try something more consistent
Base.abs(call::IdentityCall) = IdentityCall(abs(realize(call)))