#############################################################################
# Copyright (C) 2017 - 2021 Spine project consortium
# Copyright SpineInterface contributors
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
import MetaGraphsNext

"""
    Anything

A type with no fields that is the type of [`anything`](@ref).
"""
struct Anything end

"""
    UndefSpineItem

A type for indicating yet undefined Spine Items for [`write_interface`](@ref).
"""
struct UndefSpineItem end

"""
    ParameterValue

A type for representing a parameter value from a Spine db.
"""
struct ParameterValue{T}
    value::T
    metadata::Dict{Symbol,Any}
    ParameterValue(value::T) where T = new{T}(value, _parameter_value_metadata(value))
end

struct Call
    func::Union{Nothing,ParameterValue,Function}
    args::Vector
    kwargs::NamedTuple
    caller
    root_node::Ref{Any}
    function Call(func, args, kwargs, caller)
        new(func, args, kwargs, caller, nothing)
    end
end

struct _CallNode
    call
    parent::Union{_CallNode,Nothing}
    child_number::Int64
    children::Vector{_CallNode}
    value::Ref{Any}
    function _CallNode(call, parent, child_number)
        node = new(call, parent, child_number, Vector{_CallNode}(), nothing)
        if parent !== nothing
            push!(parent.children, node)
        end
        node
    end
end

"""
    Object

A type for representing an object from a Spine db; an instance of an object class.
"""
struct Object
    name::Symbol
    class_name::Union{Symbol,Nothing}
    members::Vector{Object} # Consider using a `Set`?
    groups::Vector{Object} # Consider using a `Set`?
    id::UInt64
    function Object(name, class_name, members, groups)
        id = objectid((name, class_name))
        new(name, class_name, members, groups, id)
    end
end

abstract type AbstractUpdate end

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
    actual_duration::Union{Dates.CompoundPeriod,Period}
    updates::Dict{AbstractUpdate,Union{Dates.CompoundPeriod,Period}}
    function TimeSlice(start, end_, duration, blocks)
        start > end_ && error("out of order")
        blocks = isempty(blocks) ? () : Tuple(sort(collect(blocks)))
        id = objectid((start, end_, duration, blocks))
        actual_duration = canonicalize(end_ - start)
        new(Ref(start), Ref(end_), duration, blocks, id, actual_duration, Dict())
    end
end

const ObjectLike = Union{Object,TimeSlice,Int64}
const ObjectTupleLike = Tuple{ObjectLike,Vararg{ObjectLike}}
const RelationshipLike{K} = NamedTuple{K,V} where {K,V<:ObjectTupleLike}
const EntityLike = Union{ObjectLike,RelationshipLike}

struct _TimeSliceNetwork
    time_slice_graph::MetaGraphsNext.MetaGraph
end

struct TimeSliceNetwork
    name::Symbol
    env_dict::Dict{Symbol, _TimeSliceNetwork}
    function TimeSliceNetwork(name, time_slice_graph=empty_time_slice_graph())
        env_dict = Dict(_active_env() => _TimeSliceNetwork(time_slice_graph))
        new(name, env_dict)
    end
end

const Atom = Pair{Symbol, Symbol}
const AnyAtomInClass = Pair{Symbol, Anything}
const MultiAtomSelector = Tuple{Union{Atom, AnyAtomInClass}, Vararg{Union{Atom, AnyAtomInClass}}}

abstract type ClassVertexWithEntities end

struct ObjectClassVertex <: ClassVertexWithEntities
    entities::Set{Symbol}
    entity_group_graph::MetaGraphsNext.MetaGraph
    parameter_values::Dict{Symbol, Dict{Symbol, ParameterValue}}
    parameter_defaults::Dict{Symbol, ParameterValue}
    function ObjectClassVertex()
        new(Set(), empty_entity_group_graph(), Dict(), Dict())
    end
end

struct RelationshipClassVertex <: ClassVertexWithEntities
    entities::Set{Symbol}
    atomic_dimension_choices::Vector{Vector{Symbol}}
    relationship_graph::MetaGraphsNext.MetaGraph
    parameter_values::Dict{Symbol, Dict{Symbol, ParameterValue}}
    parameter_defaults::Dict{Symbol, ParameterValue}
    function RelationshipClassVertex(atomic_dimension_choices)
        new(Set(), atomic_dimension_choices, empty_relationship_graph(length(atomic_dimension_choices)), Dict(), Dict())
    end
end

struct SuperclassVertex
    parameter_defaults::Dict{Symbol, ParameterValue}
    entity_class_graph::MetaGraphsNext.MetaGraph
    class_label::Symbol
    function SuperclassVertex(entity_class_graph, class_label)
        new(Dict(), entity_class_graph, class_label)
    end
end

abstract type EntityClass end

struct ObjectClassData
    entity_class_graph::MetaGraphsNext.MetaGraph
    vertex::ObjectClassVertex
    objects::Dict{Symbol, Object}
    parameter_defaults::Dict{Symbol, ParameterValue} # SpineOpt needs direct access
    function ObjectClassData(graph, vertex, objects)
        new(graph, vertex, objects, vertex.parameter_defaults)
    end
end

"""
    ObjectClass

A type for representing an object class from a Spine db.
"""
struct ObjectClass <: EntityClass
    name::Symbol
    env_dict::Dict{Symbol, ObjectClassData}
    function ObjectClass(name, entity_class_graph, objects)
        vertex = entity_class_graph[name]
        env_dict = Dict(_active_env() => ObjectClassData(entity_class_graph, vertex, objects))
        new(name, env_dict)
    end
end

struct RelationshipClassData
    entity_class_graph::MetaGraphsNext.MetaGraph
    vertex::RelationshipClassVertex
    object_classes::Dict{Symbol, ObjectClass}
    intact_dimension_combinations::Vector{Vector{Symbol}}
    dimension_combinations::Vector{Vector{Symbol}}
    parameter_defaults::Dict{Symbol, ParameterValue} # SpineOpt needs direct access
    function RelationshipClassData(graph, label, object_classes)
        vertex = graph[label]
        intact_combinations = atomic_dimensions(graph, label)
        unique_combinations = [uniquefy_elements(c) for c in intact_combinations]
        new(graph, vertex, object_classes, intact_combinations, unique_combinations, vertex.parameter_defaults)
    end
end

"""
    RelationshipClass

A type for representing a relationship class from a Spine db.
"""
struct RelationshipClass <: EntityClass
    name::Symbol
    env_dict::Dict{Symbol, RelationshipClassData}
    function RelationshipClass(name, entity_class_graph, object_classes)
        env_dict = Dict(_active_env() => RelationshipClassData(entity_class_graph, name, object_classes))
        new(name, env_dict)
    end
end

struct SuperclassData
    entity_class_graph::MetaGraphsNext.MetaGraph
    vertex::SuperclassVertex
    object_classes::Dict{Symbol, ObjectClass} # TODO: Check the contents! They seem to contain EVERY class when processed through SpineOpt!
    relationship_classes::Dict{Symbol, RelationshipClass}  # TODO: See above
end

"""
    Superclass

A type for representing a superclass from a Spine db.
"""
struct Superclass <: EntityClass
    name::Symbol
    env_dict::Dict{Symbol, SuperclassData}
    function Superclass(name, entity_class_graph, object_classes, relationship_classes)
        vertex = entity_class_graph[name]
        env_dict = Dict(_active_env() => SuperclassData(entity_class_graph, vertex, object_classes, relationship_classes))
        new(name, env_dict)
    end
end

struct _Parameter
    sorted_classes::Vector{EntityClass}
end

"""
    Parameter

A type for representing a parameter related to an object class or a relationship class in a Spine db.
"""
struct Parameter
    name::Symbol
    env_dict::Dict{Symbol,_Parameter}
    function Parameter(name, entity_class_graph, classes=[])
        env_dict = Dict(_active_env() => _Parameter(sort(classes, by=ClassSize(entity_class_graph),rev=true)))
        new(name, env_dict)
    end
end

struct TimeSliceRelationships
    name::Symbol
    preceding::Symbol
    succeeding::Symbol
    time_slice_graph::MetaGraphsNext.MetaGraph
end

"""
    TimeInterval

A type for representing an interval between two integer values.
"""
struct TimeInterval
    key::Symbol
    lower::Int64
    upper::Int64
end

IntersectionOfIntervals = Vector{TimeInterval}
UnionOfIntersections = Vector{IntersectionOfIntervals}
TimePattern = Dict{UnionOfIntersections,T} where {T}

"""
    TimeSeries

A type for representing a series of values in a Spine db. The index is a DateTime.
"""
struct TimeSeries{V}
    indexes::Array{DateTime,1}
    values::Array{V,1}
    ignore_year::Bool
    repeat::Bool
    function TimeSeries(inds, vals::Array{V,1}, iy, rep; merge_ok=false) where {V}
        inds, vals = copy(inds), copy(vals)
        _sort_unique!(inds, vals; merge_ok=merge_ok)
        new{V}(inds, vals, iy, rep)
    end
end

"""
    Map{K,V}

A nested general purpose indexed value corresponding to the similarly named `spinedb_api` class.

Consists of an `Array` of indexes and an `Array` of values.
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

struct Bind
    d::Dict
    function Bind()
        new(Dict())
    end
end

"""
Modify `inds` and `vals` in place, trimmed so they are both of the same size, sorted,
and with non unique elements of `inds` removed.
"""
function _sort_unique!(inds, vals; merge_ok=false)
    ind_count = length(inds)
    val_count = length(vals)
    if ind_count > val_count
        @warn("too many indices, taking only first $val_count")
        deleteat!(inds, val_count + 1 : ind_count)
    elseif val_count > ind_count
        @warn("too many values, taking only first $ind_count")
        deleteat!(vals, ind_count + 1 : val_count)
    end
    if !issorted(inds)
        p = sortperm(inds)
        inds_copy = copy(inds)
        vals_copy = copy(vals)
        for (dst, src) in enumerate(p)
            inds[dst] = inds_copy[src]
            vals[dst] = vals_copy[src]
        end
    end
    nonunique = _nonunique_positions_sorted(inds)
    if !merge_ok && !isempty(nonunique)
        n = length(nonunique)
        dupes = [inds[i] => vals[i] for i in nonunique[1 : min(n, 5)]]
        tail = n > 5 ? "... plus $(n - 5) more" : ""
        @warn("repeated indices, taking only last one: $dupes, $tail")
    end
    deleteat!(inds, nonunique)
    deleteat!(vals, nonunique)
    nothing
end

"""
Non unique positions in a sorted Array.
"""
function _nonunique_positions_sorted(arr)
    nonunique = []
    sizehint!(nonunique, length(arr))
    for (i, (x, y)) in enumerate(zip(arr[1 : end - 1], arr[2:end]))
        isequal(x, y) && push!(nonunique, i)
    end
    nonunique
end

_Scalar = Union{Nothing,Missing,Bool,Int64,Float64,Symbol,DateTime,Period}
_Indexed = Union{Array,TimePattern,TimeSeries,Map}
