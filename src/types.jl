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

"""
    Anything

A type with no fields that is the type of [`anything`](@ref).
"""
struct Anything end

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
    kwargs::Union{Iterators.Pairs,NamedTuple}
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
    members::Array{Object,1}
    groups::Array{Object,1}
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

ObjectLike = Union{Object,TimeSlice,Int64}
ObjectTupleLike = Tuple{ObjectLike,Vararg{ObjectLike}}
RelationshipLike{K} = NamedTuple{K,V} where {K,V<:ObjectTupleLike}
abstract type EntityClass end

struct _ObjectClass
    name::Symbol
    objects::Vector{ObjectLike}
    parameter_values::Dict{ObjectLike,Dict{Symbol,ParameterValue}}
    parameter_defaults::Dict{Symbol,ParameterValue}
    subclasses::Vector{Union{Symbol,EntityClass}} # Tasku: This is effectively `Vector{EntityClass}`, but needs to accommodate Symbols for now due to how subclasses are resolved in `_generate_convenience_functions`
    function _ObjectClass(name, objects, vals=Dict(), defaults=Dict(), subclasses=[])
        new(name, objects, vals, defaults, subclasses)
    end
end

"""
    ObjectClass

A type for representing an object class from a Spine db.
"""
struct ObjectClass <: EntityClass
    name::Symbol
    env_dict::Dict{Symbol,_ObjectClass}
    function ObjectClass(name, args...; mod=@__MODULE__, extend=false)
        new_ = new(name, Dict(_active_env() => _ObjectClass(name, args...)))
        spine_object_classes = _getproperty!(mod, :_spine_object_classes, Dict())
        _resolve!(spine_object_classes, name, new_, extend)
    end
end

struct _RelationshipClass
    name::Symbol
    intact_object_class_names::Vector{Symbol}
    object_class_names::Vector{Symbol}
    relationships::Vector{RelationshipLike}
    parameter_values::Dict{ObjectTupleLike,Dict{Symbol,ParameterValue}}
    parameter_defaults::Dict{Symbol,ParameterValue}
    row_map::Dict
    row_map_lock::ReentrantLock
    function _RelationshipClass(name, intact_cls_names, object_tuples, vals=Dict(), defaults=Dict())
        cls_names = _fix_name_ambiguity(intact_cls_names)
        rc = new(
            name,
            intact_cls_names,
            cls_names,
            [],
            vals,
            defaults,
            Dict(),
            ReentrantLock(),
        )
        rels = [(; zip(cls_names, objects)...) for objects in object_tuples]
        _append_relationships!(rc, rels)
        rc
    end
end

"""
    RelationshipClass

A type for representing a relationship class from a Spine db.
"""
struct RelationshipClass <: EntityClass
    name::Symbol
    env_dict::Dict{Symbol,_RelationshipClass}
    function RelationshipClass(name, args...; mod=@__MODULE__, extend=false)
        new_ = new(name, Dict(_active_env() => _RelationshipClass(name, args...)))
        spine_relationship_classes = _getproperty!(mod, :_spine_relationship_classes, Dict())
        _resolve!(spine_relationship_classes, name, new_, extend)
    end
end

"""
    _fix_name_ambiguity(intact_name_list::Vector{Symbol})

Append an increasing integer to each repeated element in `name_list`, and return a new modified `name_list`.

See also [`_fix_name_ambiguity!`](@ref).
"""
function _fix_name_ambiguity(intact_name_list::Vector{Symbol})
    name_list = copy(intact_name_list)
    for ambiguous in Iterators.filter(name -> count(name_list .== name) > 1, unique(name_list))
        for (k, index) in enumerate(findall(name_list .== ambiguous))
            name_list[index] = Symbol(name_list[index], k)
        end
    end
    name_list
end

"""
    _fix_name_ambiguity!(name_list::Vector{Symbol}, intact_name_list::Vector{Symbol})

Replace `name_list` by `_fix_name_ambiguity(intact_name_list)`.

See also [`_fix_name_ambiguity!`](@ref).
"""
function _fix_name_ambiguity!(name_list::Vector{Symbol}, intact_name_list::Vector{Symbol})
    new_name_list = _fix_name_ambiguity(intact_name_list)
    for (i, new_name) in enumerate(new_name_list)
        name_list[i] = new_name
    end
    name_list
end

struct _Parameter
    name::Symbol
    classes::Vector{EntityClass}
    _Parameter(name, classes=[]) = new(name, classes)
end

"""
    Parameter

A type for representing a parameter related to an object class or a relationship class in a Spine db.
"""
struct Parameter
    name::Symbol
    env_dict::Dict{Symbol,_Parameter}
    function Parameter(name, args...; mod=@__MODULE__, extend=false)
        new_ = new(name, Dict(_active_env() => _Parameter(name, args...)))
        spine_parameters = _getproperty!(mod, :_spine_parameters, Dict())
        _resolve!(spine_parameters, name, new_, extend)
    end
end

function _resolve!(elements, name, new_, extend)
    current = get(elements, name, nothing)
    if current === nothing
        elements[name] = new_
    else
        _env_merge!(current, new_, extend)
    end
end

function _env_merge!(current, new, extend)
    env = _active_env()
    if haskey(current.env_dict, env) && extend
        merge!(current, new)
    else
        current.env_dict[env] = new.env_dict[env]
    end
    current
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
