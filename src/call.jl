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

struct Call
    func
    args
    kwargs
    _is_dynamic::Bool
    function Call(func, args, kwargs)
        _is_dynamic = any(is_dynamic(arg) for arg in (args..., kwargs...))
        new(func, args, kwargs, _is_dynamic)
    end
end

# Outer constructors
Call(other::Call) = copy(other)
_identity(x) = x
Call(n) = Call(_identity, (n,), ())
Base.show(::IO, ::typeof(_identity)) = nothing

# utility
Base.copy(c::Call) = Call(c.func, c.args, c.kwargs)
Base.convert(::Type{Call}, x::T) where {T<:Real} = Call(x)
function Base.show(io::IO, call::Call)
    call_str = string(call.func)
    args_str = join(call.args, ", ")
    kwargs_str = join([join(kw, "=") for kw in pairs(call.kwargs)], ", ")
    args_str = join(filter(!isempty, [args_str, kwargs_str]), "; ")
    print(io, string(call.func, "(", args_str, ")"))
end

# realize
realize(x) = x

function realize(call::Call)
    args = (realize(arg) for arg in call.args)
    kwargs = (k => realize(v) for (k, v) in pairs(call.kwargs))
    call.func(args...; kwargs...)
end

is_dynamic(x) = false
is_dynamic(x::TimeSlice) = true
is_dynamic(call::Call) = call._is_dynamic

# operators
Base.zero(::Type{Call}) where T = Call(0.0)
Base.zero(::Call) = Call(0.0)
Base.one(::Type{Call}) = Call(1.0)
Base.one(::Call) = Call(1.0)
Base.:+(x::Call) = x
Base.:+(x::Call, y) = Call(+, (x, y), ())
Base.:+(x, y::Call) = Call(+, (x, y), ())
Base.:+(x::Call, y::Call) = Call(+, (x, y), ())
Base.:-(x::Call) = Call(-, (0.0, x), ())
Base.:-(x::Call, y) = Call(-, (x, y), ())
Base.:-(x, y::Call) = Call(-, (x, y), ())
Base.:-(x::Call, y::Call) = Call(-, (x, y), ())
Base.:*(x::Call, y) = Call(*, (x, y), ())
Base.:*(x, y::Call) = Call(*, (x, y), ())
Base.:*(x::Call, y::Call) = Call(*, (x, y), ())
Base.:/(x::Call, y) = Call(/, (x, y), ())
Base.:/(x, y::Call) = Call(/, (x, y), ())
Base.:/(x::Call, y::Call) = Call(/, (x, y), ())

macro call(expr::Expr)
    # TODO: finish this
    expr.head == :call || error("@call must be used with function calls")
    @show expr.args[3].args
    @show [(a, typeof(a)) for a in expr.args]
    func = esc(expr.args[1])
    @show args = Tuple(arg for arg in expr.args[2:end] if !(arg isa Expr))
    @show kwargs = (; (arg.args for arg in expr.args[2:end] if arg isa Expr && arg.head == :kw)...)
    :(Call($func, $args, $kwargs))
end

# Override `getindex` for `Parameter` so we can call `parameter[...]` and get a `Call`
Base.getindex(parameter::Parameter, inds::NamedTuple) = Call(parameter, (), inds)