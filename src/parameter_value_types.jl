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

(p::NoValue)(;kwargs...) = nothing
(p::ScalarValue)(;kwargs...) = p.value

function (p::ArrayValue)(;i::Union{Int64,Nothing}=nothing)
    i === nothing && error("argument `i` missing")
    p.value[i]
end

function (p::DictValue)(;k::Union{T,Nothing}=nothing) where T
    k === nothing && error("argument `k` missing")
    p.value[t]
end

# Iterate single ScalarValue as collection
ScalarValue(s::String) = ScalarValue(Symbol(s))

Base.iterate(v::ScalarValue) = iterate((v,))
Base.iterate(v::ScalarValue, state::T) where T = iterate((v,), state)
Base.length(v::ScalarValue) = 1
