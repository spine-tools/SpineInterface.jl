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
struct NoValue
end

struct ScalarValue{T}
    value::T
end

struct ArrayValue
    value::Array
end

struct DictValue
    value::Dict
end

# Outer constructors
ScalarValue(s::String) = ScalarValue(Symbol(s))

# Callers
(p::NoValue)(;kwargs...) = nothing
(p::ScalarValue)(;kwargs...) = p.value

function (p::ArrayValue)(;i::Union{Int64,Nothing}=nothing)
    if i === nothing
        @warn("argument `i` missing, returning the whole array")
        p.value
    else
        p.value[i]
    end
end

function (p::DictValue)(;k::Union{T,Nothing}=nothing) where T
    if k === nothing
        @warn("argument `k` missing, returning the whole dictionary")
        p.value
    else
        p.value[t]
    end
end

# Iterate single ScalarValue as collection
Base.iterate(v::ScalarValue) = iterate((v,))
Base.iterate(v::ScalarValue, state::T) where T = iterate((v,), state)
Base.length(v::ScalarValue) = 1
# Compare ScalarValue
Base.isless(v1::ScalarValue, v2::ScalarValue) = v1.value < v2.value
# Show ScalarValue
Base.show(io::IO, v::ScalarValue) = print(io, v.value)
