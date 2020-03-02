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
end

# `realize`
realize(x) = x

function realize(call::Call)
    args = realize.(call.args)
    kwargs = Dict(k => realize(v) for (k, v) in pairs(call.kwargs))
    call.func(args...; kwargs...)
end

# print
function Base.show(io::IO, call::Call)
    call_str = string(call.func)
    args_str = join(call.args, ", ")
    kwargs_str = join([join(kw, "=") for kw in pairs(call.kwargs)], ", ")
    args_str = join(filter(!isempty, [args_str, kwargs_str]), "; ")
    print(io, string(call.func, "(", args_str, ")"))
end

# `Call` constructors
Call(other::Call) = copy(other)
_identity(x) = x
Base.show(::IO, ::typeof(_identity)) = nothing
Call(n) = Call(_identity, (n,), ())

# operators
Base.zero(::Call) = Call(0.0)
Base.zero(::Type{Call}) = Call(0.0)
Base.one(::Type{Call}) = Call(1.0)
Base.:+(c::Call) = c
Base.:-(c::Call) = Call(-, (0.0, c), ())
Base.:+(c::Call, x::Call) = Call(+, (c, x), ())
Base.:-(c::Call, x::Call) = Call(-, (c, x), ())
Base.:*(c::Call, x::Call) = Call(*, (c, x), ())
Base.:/(c::Call, x::Call) = Call(/, (c, x), ())
Base.:+(c::Call, x) = Call(+, (c, x), ())
Base.:-(c::Call, x) = Call(-, (c, x), ())
Base.:*(c::Call, x) = Call(*, (c, x), ())
Base.:/(c::Call, x) = Call(/, (c, x), ())
Base.:+(x, c::Call) = Call(+, (x, c), ())
Base.:-(x, c::Call) = Call(-, (x, c), ())
Base.:*(x, c::Call) = Call(*, (x, c), ())
Base.:/(x, c::Call) = Call(/, (x, c), ())

Base.copy(c::Call) = Call(c.func, c.args, c.kwargs)

Base.convert(::Type{Call}, x::T) where {T<:Real} = Call(x)

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

