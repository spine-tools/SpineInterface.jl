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
    Anything

A type with no fields that is the type of [`anything`](@ref).
"""
struct Anything end

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
    callbacks::Dict  # callbacks by timeout
    function TimeSlice(start, end_, duration, blocks)
        start > end_ && error("out of order")
        blocks = isempty(blocks) ? () : Tuple(sort(collect(blocks)))
        id = objectid((start, end_, duration, blocks))
        new(Ref(start), Ref(end_), duration, blocks, id, Dict())
    end
end

ObjectLike = Union{Object,TimeSlice,Int64}
ObjectTupleLike = Tuple{Vararg{ObjectLike}}
RelationshipLike{K} = NamedTuple{K,V} where {K,V<:ObjectTupleLike}

"""
    ParameterValue

A type for representing a parameter value from a Spine db.
"""
struct ParameterValue{T}
    value::T
    metadata::Dict
    ParameterValue(value::T) where T = new{T}(value, _parameter_value_metadata(value))
end

"""
    ObjectClass

A type for representing an object class from a Spine db.
"""
struct ObjectClass
    name::Symbol
    entities::DataFrame
    default_parameter_values::Dict{Symbol,Any}
    ObjectClass(name, entities::DataFrame, defaults=Dict()) = new(name, entities, defaults)
end

"""
    RelationshipClass

A type for representing a relationship class from a Spine db.
"""
struct RelationshipClass
    name::Symbol
    intact_object_class_names::Array{Symbol,1}
    entities::DataFrame
    default_parameter_values::Dict{Symbol,Any}
    function RelationshipClass(name, intact_cls_names, entities::DataFrame, defaults=Dict())
        new(name, intact_cls_names, entities, defaults)
    end
end

"""
    Parameter

A type for representing a parameter related to an object class or a relationship class in a Spine db.
"""
struct Parameter
    name::Symbol
    classes::Array{Union{ObjectClass,RelationshipClass},1}
    Parameter(name, classes=[]) = new(name, classes)
end

struct _ClassAccess{N,H}
    df::AbstractDataFrame
    _ClassAccess(df) = new{ncol(df), Tuple(propertynames(df))}(df)
end

#=
innerjoin(
    innerjoin(
        node__temporal_block(node=node, temporal_block=temporal_block),
        temporal_block_group(group=temporal_block); on=[:temporal_block => :group]
    ),
    temporal_block__t(temporal_block=temporal_block, t=t); on=[:member => :temporal_block]
)
=#

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

_Scalar = Union{Nothing,Bool,Int64,Float64,Symbol,DateTime,Period}
_Indexed = Union{TimePattern,TimeSeries,Map}

struct _StartRef
    time_slice::TimeSlice
end

_CallExpr = Tuple{Symbol,NamedTuple}

struct Call
    func::Union{Nothing,ParameterValue,Function}
    args::Vector
    kwargs::NamedTuple
    call_expr::Union{_CallExpr,Nothing}
end
