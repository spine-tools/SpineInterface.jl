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
    AbstractObject

Supertype for [`Object`](@ref) and [`TimeSlice`](@ref).
"""
abstract type AbstractObject end

"""
    AbstractParameterValue

Supertype for all parameter value callables.
"""
abstract type AbstractParameterValue end

abstract type AbstractTimeSeriesParameterValue <: AbstractParameterValue end

abstract type Call end

"""
    Anything

A type with no fields that is the type of [`anything`](@ref).
"""
struct Anything end

"""
    Object

A type for representing an object in a Spine db.
"""
struct Object <: AbstractObject
    name::Symbol
    id::UInt64
end

ObjectLike = Union{T,Int64} where T<:AbstractObject

RelationshipLike{K} = NamedTuple{K,V} where {K,V<:Tuple{Vararg{ObjectLike}}}

struct ObjectIdFactory
    max_object_id::Ref{UInt64}
    ObjectIdFactory(i) = new(Ref(i))
end

struct ObjectClass
    name::Symbol
    objects::Array{ObjectLike,1}
    parameter_values::Dict{Object,Dict{Symbol,AbstractParameterValue}}
    parameter_defaults::Dict{Symbol,AbstractParameterValue}
end

struct RelationshipClass
    name::Symbol
    object_class_names::Array{Symbol,1}
    relationships::Array{RelationshipLike,1}
    parameter_values::Dict{Tuple{Vararg{Object}},Dict{Symbol,AbstractParameterValue}}
    parameter_defaults::Dict{Symbol,AbstractParameterValue}
    lookup_cache::Dict{Bool,Dict}
    RelationshipClass(name, obj_cls_names, rels, vals, defaults) =
        new(name, obj_cls_names, rels, vals, defaults, Dict(:true => Dict(), :false => Dict()))
end

struct Parameter
    name::Symbol
    classes::Array{Union{ObjectClass,RelationshipClass},1}
end

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

struct TimeSliceMap
    time_slices::Array{TimeSlice,1}
    index::Array{Int64,1}
    start::DateTime
    end_::DateTime
end

# parameter value types
# types returned by the parsing function `spinedb_api.from_database`
# are automatically converted to these using `PyCall.pytype_mapping` as defined in the module's __init__ method.
# This allows us to mutiple dispatch `callable`
struct DateTime_
    value::DateTime
end

struct Duration
    value::Period
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

"""
    Map{K,V}

A nested general purpose indexed value corresponding to the similarly named `spinedb_api` class.

Consists of an `indexes::Array{K,1}`, a `values::Array{V,1}` of matching length, and a `index_type::DataType` defining
the type of `K`. See `MapParameterValue` for the corresponding `AbstractParameterValue` type for accessing `Map` type
parameters.
"""
struct Map{K,V}
    indexes::Array{K,1}
    values::Array{V,1}
    index_type::DataType
    function Map(inds::Array{K,1}, vals::Array{V,1}, itype::DataType) where {K,V}
        if length(inds) != length(vals)
            error("`indexes` and `values` must be of the same length!")
        end
        new{K,V}(inds, vals, itype)
    end
end

# AbstractParameterValue subtypes
# These are wrappers around some standard Julia types and our parameter value types, that override the call operator
struct NothingParameterValue <: AbstractParameterValue
end

struct ScalarParameterValue{T} <: AbstractParameterValue
    value::T
end

struct ArrayParameterValue{T,N} <: AbstractParameterValue
    value::Array{T,N}
end

struct TimePatternParameterValue{T} <: AbstractParameterValue
    value::TimePattern{T}
end

struct TimeSeriesMap
    index::Array{Int64,1}
    map_start::DateTime
    map_end::DateTime
end

struct StandardTimeSeriesParameterValue{V} <: AbstractTimeSeriesParameterValue
    value::TimeSeries{V}
    t_map::TimeSeriesMap
end

struct RepeatingTimeSeriesParameterValue{V} <: AbstractTimeSeriesParameterValue
    value::TimeSeries{V}
    span::Union{Period,Nothing}
    valsum::V
    len::Int64
    t_map::TimeSeriesMap
end

struct MapParameterValue{K,V} <: AbstractParameterValue
    value::Map{K,V}
end

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
