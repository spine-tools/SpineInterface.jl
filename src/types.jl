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
"""
    Anything

A type with no fields that is the type of [`anything`](@ref).
"""
struct Anything
end

"""
    anything

The singleton instance of type [`Anything`](@ref), used to specify *all-pass* filters
in calls to [`RelationshipClass()`](@ref).
"""
anything = Anything()

Base.intersect(::Anything, s) = s
Base.intersect(s::T, ::Anything) where T<:AbstractArray = s
Base.intersect(s::T, ::Anything) where T<:AbstractSet = s
Base.in(item, ::Anything) = true
Base.show(io::IO, ::Anything) = print(io, "anything")
Base.hash(::Anything) = zero(UInt64)

"""
    ObjectLike

Supertype for [`Object`](@ref) and [`TimeSlice`](@ref).
"""
abstract type ObjectLike end

"""
    Object

A type for representing an object in a Spine db.
"""
struct Object <: ObjectLike
    name::Symbol
    id::UInt64
end

Object(name::AbstractString, id) = Object(Symbol(name), id)

# Iterate single `Object` as collection
Base.iterate(o::Object) = iterate((o,))
Base.iterate(o::Object, state::T) where T = iterate((o,), state)
Base.length(o::Object) = 1
# Compare `Object`s
Base.isless(o1::Object, o2::Object) = o1.name < o2.name
Base.show(io::IO, o::Object) = print(io, o.name)
Base.hash(o::Object) = o.id

Relationship = NamedTuple{K,V} where {K,V<:Tuple{Vararg{ObjectLike}}}

struct ObjectClass
    name::Symbol
    objects::Array{Object,1}
    parameter_values::Dict{Object,NamedTuple}
end

struct RelationshipClass
    name::Symbol
    object_class_names::Tuple{Vararg{Symbol}}
    relationships::Array{Relationship,1}
    parameter_values::Dict{Tuple{Vararg{Object}},NamedTuple}
    lookup_cache::Dict
    RelationshipClass(name, obj_cls_names, rels, vals) = new(name, obj_cls_names, rels, vals, Dict())
end

RelationshipClass(name, obj_cls_names, rels) = RelationshipClass(name, obj_cls_names, rels, Dict())

struct Parameter
    name::Symbol
    classes::Array{Union{ObjectClass,RelationshipClass},1}
end

Parameter(name) = Parameter(name, [])

Base.show(io::IO, p::Parameter) = print(io, p.name)
Base.show(io::IO, oc::ObjectClass) = print(io, oc.name)
Base.show(io::IO, rc::RelationshipClass) = print(io, rc.name)

"""
    (<oc>::ObjectClass)(;<keyword arguments>)

An `Array` of [`Object`](@ref) instances corresponding to the objects in class `oc`.

# Arguments

For each parameter associated to `oc` in the database there is a keyword argument
named after it. The purpose is to filter the result by specific values of that parameter.

# Examples

```jldoctest
julia> using SpineInterface;

julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");

julia> using_spinedb(url)

julia> sort(node())
5-element Array{Object,1}:
 Dublin
 Espoo
 Leuven
 Nimes
 Sthlm

julia> commodity(state_of_matter=:gas)
1-element Array{Object,1}:
 wind

```
"""
function (oc::ObjectClass)(;kwargs...)
    isempty(kwargs) && return oc.objects
    cond(o) = all(get(oc.parameter_values[o], p, NothingCallable())() === v for (p, v) in kwargs)
    filter(cond, oc.objects)
end

function (oc::ObjectClass)(name::Symbol)
    i = findfirst(o -> o.name == name, oc.objects)
    i != nothing && return oc.objects[i]
end

"""
    (<rc>::RelationshipClass)(;<keyword arguments>)

An `Array` of [`Object`](@ref) tuples corresponding to the relationships of class `rc`.

# Arguments

- For each object class in `rc` there is a keyword argument named after it.
  The purpose is to filter the result by an object or list of objects of that class,
  or to accept all objects of that class by specifying `anything` for this argument.
- `_compact::Bool=true`: whether or not filtered object classes should be removed from the resulting tuples.
- `_default=[]`: the default value to return in case no relationship passes the filter.

# Examples

```jldoctest
julia> using SpineInterface;

julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");

julia> using_spinedb(url)

julia> sort(node__commodity())
5-element Array{NamedTuple,1}:
 (node = Dublin, commodity = wind)
 (node = Espoo, commodity = wind)
 (node = Leuven, commodity = wind)
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=:water)
2-element Array{Object,1}:
 Nimes
 Sthlm

julia> node__commodity(node=(:Dublin, :Espoo))
1-element Array{Object,1}:
 wind

julia> sort(node__commodity(node=anything))
2-element Array{Object,1}:
 water
 wind

julia> sort(node__commodity(commodity=:water, _compact=false))
2-element Array{NamedTuple,1}:
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=:gas, _default=:nogas)
:nogas

```
"""
function (rc::RelationshipClass)(;_compact::Bool=true, _default::Any=[], kwargs...)
    isempty(kwargs) && return rc.relationships
    lookup_key = tuple((_simplify(get(kwargs, oc, anything)) for oc in rc.object_class_names)...)
    relationships = get!(rc.lookup_cache, lookup_key) do
        cond(rel) = all(rel[rc] in r for (rc, r) in kwargs)
        filter(cond, rc.relationships)
    end
    isempty(relationships) && return _default
    _compact || return relationships
    head = setdiff(rc.object_class_names, keys(kwargs))
    if length(head) == 1
        unique(x[head...] for x in relationships)
    elseif length(head) > 1
        unique(NamedTuple{tuple(head...)}([x[k] for k in head]) for x in relationships)
    else
        _default
    end
end

_simplify(x) = x
_simplify(arr::T) where T<:AbstractArray = (length(arr) == 1) ? first(arr) : tuple(arr...)


"""
    (<p>::Parameter)(;<keyword arguments>)

The value of parameter `p` for a given object or relationship.

# Arguments

- For each object class associated with `p` there is a keyword argument named after it.
  The purpose is to retrieve the value of `p` for a specific object.
- For each relationship class associated with `p`, there is a keyword argument named after each of the
  object classes involved in it. The purpose is to retrieve the value of `p` for a specific relationship.
- `i::Int64`: a specific index to retrieve in case of an array value (ignored otherwise).
- `t::TimeSlice`: a specific time-index to retrieve in case of a time-varying value (ignored otherwise).
- `_strict::Bool`: whether to raise an error or return `nothing` if the parameter is not specified for the given arguments.


# Examples

```jldoctest
julia> using SpineInterface;

julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");

julia> using_spinedb(url)

julia> tax_net_flow(node=:Sthlm, commodity=:water)
4

julia> demand(node=:Sthlm, i=1)
21

```
"""
function (p::Parameter)(;i=nothing, t=nothing, _strict=true, kwargs...)
    callable = _lookup_callable(p; kwargs...)
    callable != nothing && return callable(i=i, t=t)
    _strict && error("parameter $p is not specified for argument(s) $(kwargs...)")
    nothing
end

function _lookup_callable(p::Parameter; kwargs...)
    for class in p.classes
        lookup_key = _lookup_key(class; kwargs...)
        lookup_key in keys(class.parameter_values) || continue
        parameter_values = class.parameter_values[lookup_key]
        return parameter_values[p.name]
    end
end

_lookup_key(class::ObjectClass; kwargs...) = get(kwargs, class.name, nothing)

function _lookup_key(class::RelationshipClass; kwargs...)
    objects = [get(kwargs, oc, nothing) for oc in class.object_class_names]
    nothing in objects && return nothing
    tuple(objects...)
end

