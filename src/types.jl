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

"""
    AbstractParameterValue

Supertype for all parameter value callables.
"""
abstract type AbstractParameterValue end

abstract type AbstractTimeSeriesParameterValue <: AbstractParameterValue end

"""
    Anything

A type with no fields that is the type of [`anything`](@ref).
"""
struct Anything end

"""
    Object

A type for representing an object in a Spine db.
"""
struct Object
    name::Symbol
    class_name::Union{Symbol,Nothing}
    members::Array{Object,1}
    groups::Array{Object,1}
    id::UInt64
    function Object(name, class_name, members, groups)
        id = objectid((name, class_name))
        new(name, class_name, members, groups, id)
    end
end

"""
    TimeSlice

A type for representing a slice of time.
"""
struct TimeSlice
    start::Ref{DateTime}
    end_::Ref{DateTime}
    duration::Float64
    blocks::NTuple{N,Object} where {N}
    id::UInt64
    function TimeSlice(start, end_, duration, blocks)
        start > end_ && error("out of order")
        id = objectid((start, end_, duration, blocks))
        new(Ref(start), Ref(end_), duration, blocks, id)
    end
end

ObjectLike = Union{Object,TimeSlice,Int64}

RelationshipLike{K} = NamedTuple{K,V} where {K,V<:Tuple{Vararg{ObjectLike}}}

struct ObjectClass
    name::Symbol
    objects::Array{ObjectLike,1}
    parameter_values::Dict{ObjectLike,Dict{Symbol,AbstractParameterValue}}
    parameter_defaults::Dict{Symbol,AbstractParameterValue}
    ObjectClass(name, objects, vals=Dict(), defaults=Dict()) = new(name, objects, vals, defaults)
end

struct RelationshipClass
    name::Symbol
    intact_object_class_names::Array{Symbol,1}
    object_class_names::Array{Symbol,1}
    relationships::Array{RelationshipLike,1}
    parameter_values::Dict{Tuple{Vararg{ObjectLike}},Dict{Symbol,AbstractParameterValue}}
    parameter_defaults::Dict{Symbol,AbstractParameterValue}
    lookup_cache::Dict{Bool,Dict}
    function RelationshipClass(name, intact_cls_names, object_tuples, vals=Dict(), defaults=Dict())
        cls_names = _fix_name_ambiguity(intact_cls_names)
        rels = [(; zip(cls_names, objects)...) for objects in object_tuples]
        new(name, intact_cls_names, cls_names, rels, vals, defaults, Dict(:true => Dict(), :false => Dict()))
    end
end

struct Parameter
    name::Symbol
    classes::Array{Union{ObjectClass,RelationshipClass},1}
    Parameter(name, classes=[]) = new(name, classes)
end

struct TimeInterval
    key::Symbol
    lower::Int64
    upper::Int64
end

IntersectionOfIntervals = Vector{TimeInterval}

UnionOfIntersections = Vector{IntersectionOfIntervals}

TimePattern = Dict{UnionOfIntersections,T} where {T}

struct TimeSeries{V}
    indexes::Array{DateTime,1}
    values::Array{V,1}
    ignore_year::Bool
    repeat::Bool
    function TimeSeries(inds, vals::Array{V,1}, iy, rep) where {V}
        inds, vals = copy(inds), copy(vals)
        _sort_unique!(inds, vals)
        new{V}(inds, vals, iy, rep)
    end
end

"""
    Map{K,V}

A nested general purpose indexed value corresponding to the similarly named `spinedb_api` class.

Consists of an `Array` of indexes and an `Array` of values.
See `MapParameterValue` for the corresponding `AbstractParameterValue` type for accessing `Map` type
parameters.
"""
struct Map{K,V}
    indexes::Array{K,1}
    values::Array{V,1}
    function Map(inds::Array{K,1}, vals::Array{V,1}) where {K,V}
        inds, vals = copy(inds), copy(vals)
        _sort_unique!(inds, vals)
        new{K,V}(inds, vals)
    end
end

# AbstractParameterValue subtypes
struct NothingParameterValue <: AbstractParameterValue end

struct ScalarParameterValue{T} <: AbstractParameterValue
    value::T
end

struct ArrayParameterValue{T,N} <: AbstractParameterValue
    value::Array{T,N}
end

struct TimePatternParameterValue{T} <: AbstractParameterValue
    value::TimePattern{T}
end

struct StandardTimeSeriesParameterValue{V} <: AbstractTimeSeriesParameterValue
    value::TimeSeries{V}
end

struct RepeatingTimeSeriesParameterValue{V} <: AbstractTimeSeriesParameterValue
    value::TimeSeries{V}
    span::Union{Period,Nothing}
    valsum::V
    len::Int64
end

struct MapParameterValue{K,V} <: AbstractParameterValue where {V<:AbstractParameterValue}
    value::Map{K,V}
end

TimeVaryingParameterValue = Union{AbstractTimeSeriesParameterValue,TimePatternParameterValue}

_CallExpr = Tuple{Symbol,NamedTuple}

struct Call
    call_expr::Union{_CallExpr,Nothing}
    func::Union{Nothing,Function,AbstractParameterValue}
    args::Array{S,1} where S
    kwargs::NamedTuple
end

struct _DateTimeRef
    ref::Ref{DateTime}
end
