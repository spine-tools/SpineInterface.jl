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
struct Anything end

"""
    anything

The singleton instance of type [`Anything`](@ref), used to specify *all-pass* filters
in calls to [`RelationshipClass()`](@ref).
"""
anything = Anything()

"""
    AbstractObject

Supertype for [`Object`](@ref) and [`TimeSlice`](@ref).
"""
abstract type AbstractObject end

"""
    Object

A type for representing an object in a Spine db.
"""
struct Object <: AbstractObject
    name::Symbol
    id::UInt64
end

Object(name::AbstractString, args...) = Object(Symbol(name), args...)

ObjectLike = Union{AbstractObject,Int64}

Relationship{K} = NamedTuple{K,V} where {K,V<:Tuple{Vararg{ObjectLike}}}

abstract type AbstractCallable end

struct ObjectClass
    name::Symbol
    objects::Array{Object,1}
    parameter_values::Dict{Object,Dict{Symbol,AbstractCallable}}
end

ObjectClass(name, objects) = ObjectClass(name, objects, Dict())

struct RelationshipClass
    name::Symbol
    object_class_names::Array{Symbol,1}
    relationships::Array{Relationship,1}
    parameter_values::Dict{Tuple{Vararg{Object}},Dict{Symbol,AbstractCallable}}
    lookup_cache::Dict{Bool,Dict}
    RelationshipClass(name, obj_cls_names, rels, vals) =
        new(name, obj_cls_names, rels, vals, Dict(:true => Dict(), :false => Dict()))
end

RelationshipClass(name, obj_cls_names, rels) = RelationshipClass(name, obj_cls_names, rels, Dict())

struct Parameter
    name::Symbol
    classes::Array{Union{ObjectClass,RelationshipClass},1}
end

Parameter(name) = Parameter(name, [])


"""
    TimeSlice

A type for representing a slice of time.
"""
struct TimeSlice <: AbstractObject
    start::Ref{DateTime}
    end_::Ref{DateTime}
    duration::Float64
    blocks::NTuple{N,Object} where N
    id::UInt64
    function TimeSlice(start, end_, duration, blocks)
        start > end_ && error("out of order")
        id = objectid((start, end_, duration, blocks))
        new(Ref(start), Ref(end_), duration, blocks, id)
    end
end

# Special parameter value types
# types returned by the parsing function `spinedb_api.from_database`
# are automatically converted to these using `PyCall.pytype_mapping` as defined in the module's __init__ method.
# This allows us to mutiple dispatch `callable` below
struct DateTime_
    value::DateTime
end

abstract type DurationLike end

struct ScalarDuration <: DurationLike
    value::Period
end

struct ArrayDuration <: DurationLike
    value::Array{Period,1}
end

struct Array_{T}
    value::Array{T,1}
end

"""
    PeriodCollection
"""
struct PeriodCollection
    Y::Union{Array{UnitRange{Int64},1},Nothing}
    M::Union{Array{UnitRange{Int64},1},Nothing}
    D::Union{Array{UnitRange{Int64},1},Nothing}
    WD::Union{Array{UnitRange{Int64},1},Nothing}
    h::Union{Array{UnitRange{Int64},1},Nothing}
    m::Union{Array{UnitRange{Int64},1},Nothing}
    s::Union{Array{UnitRange{Int64},1},Nothing}
    function PeriodCollection(;Y=nothing, M=nothing, D=nothing, WD=nothing, h=nothing, m=nothing, s=nothing)
        new(Y, M, D, WD, h, m, s)
    end
end

TimePattern = Dict{PeriodCollection,T} where T

struct TimeSeries{V}
    indexes::Array{DateTime,1}
    values::Array{V,1}
    ignore_year::Bool
    repeat::Bool
    function TimeSeries(inds, vals::Array{V,1}, iy, rep) where {V}
        if length(inds) != length(vals)
            error("lengths don't match")
        end
        new{V}(inds, vals, iy, rep)
    end
end

# AbstractCallable subtypes
# These are wrappers around standard Julia types and our special types above,
# that override the call operator

struct NothingCallable <: AbstractCallable
end

struct ScalarCallable{T} <: AbstractCallable
    value::T
end

struct ArrayCallable{T,N} <: AbstractCallable
    value::Array{T,N}
end

struct TimePatternCallable{T} <: AbstractCallable
    value::TimePattern{T}
end

## Time series map
struct TimeSeriesMap
    index::Array{Int64,1}
    map_start::DateTime
    map_end::DateTime
end

abstract type AbstractTimeSeriesCallable <: AbstractCallable end

struct StandardTimeSeriesCallable{V} <: AbstractTimeSeriesCallable
    value::TimeSeries{V}
    t_map::TimeSeriesMap
end

struct RepeatingTimeSeriesCallable{V} <: AbstractTimeSeriesCallable
    value::TimeSeries{V}
    span::Union{Period,Nothing}
    valsum::V
    len::Int64
    t_map::TimeSeriesMap
end

# Required outer constructors
ScalarCallable(s::String) = ScalarCallable(Symbol(s))

function TimeSeriesCallable(ts::TimeSeries{V}) where {V}
    t_map = TimeSeriesMap(ts.indexes)
    if ts.repeat
        span = ts.indexes[end] - ts.indexes[1]
        valsum = sum(ts.values)
        len = length(ts.values)
        RepeatingTimeSeriesCallable(ts, span, valsum, len, t_map)
    else
        StandardTimeSeriesCallable(ts, t_map)
    end
end

abstract type Call end

struct IdentityCall{T} <: Call
    value::T
end

struct OperatorCall <: Call
    operator::Function
    args::Tuple
end

struct ParameterCall <: Call
    parameter::Parameter
    kwargs::NamedTuple
end

Base.intersect(::Anything, s) = s
Base.intersect(s::T, ::Anything) where T<:AbstractArray = s
Base.intersect(s::T, ::Anything) where T<:AbstractSet = s
Base.in(item, ::Anything) = true
Base.show(io::IO, ::Anything) = print(io, "anything")
Base.hash(::Anything) = zero(UInt64)

# Iterate single `Object` as collection
Base.iterate(o::Object) = iterate((o,))
Base.iterate(o::Object, state::T) where T = iterate((o,), state)
Base.length(o::Object) = 1
# Compare `Object`s
Base.isless(o1::Object, o2::Object) = o1.name < o2.name
Base.show(io::IO, o::Object) = print(io, o.name)
Base.:(==)(o1::Object, o2::Object) = o1.id == o2.id

Base.hash(o::Object) = o.id
Base.hash(r::Relationship{K}) where {K} = hash(values(r))

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
    function cond(o)
        for (p, v) in kwargs
            value = get(oc.parameter_values[o], p, nothing)
            (value !== nothing && value() === v) || return false
        end
        true
    end
    filter(cond, oc.objects)
end

function (oc::ObjectClass)(name::Symbol)
    i = findfirst(o -> o.name == name, oc.objects)
    i != nothing && return oc.objects[i]
    nothing
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
    lookup_key = Tuple(_immutable(get(kwargs, oc, anything)) for oc in rc.object_class_names)
    relationships = get!(rc.lookup_cache[_compact], lookup_key) do
        cond(rel) = all(rel[rc] in r for (rc, r) in kwargs)
        filtered = filter(cond, rc.relationships)
        if !_compact
            filtered
        else
            object_class_names = setdiff(rc.object_class_names, keys(kwargs))
            if isempty(object_class_names)
                []
            elseif length(object_class_names) == 1
                unique(x[object_class_names[1]] for x in filtered)
            else
                unique(NamedTuple{Tuple(object_class_names)}([x[k] for k in object_class_names]) for x in filtered)
            end
        end
    end
    if !isempty(relationships)
        relationships
    else
        _default
    end
end

_immutable(x) = x
_immutable(arr::T) where T<:AbstractArray = (length(arr) == 1) ? first(arr) : Tuple(arr)


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
        parameter_values = get(class.parameter_values, lookup_key, nothing)
        parameter_values === nothing && continue
        return parameter_values[p.name]
    end
end

_lookup_key(class::ObjectClass; kwargs...) = get(kwargs, class.name, nothing)

function _lookup_key(class::RelationshipClass; kwargs...)
    objects = Tuple(get(kwargs, oc, nothing) for oc in class.object_class_names)
    nothing in objects && return nothing
    objects
end

