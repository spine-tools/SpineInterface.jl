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

Entity(name::AbstractString, args...) = Entity(Symbol(name), args...)
Entity(name::AbstractString, class_name::AbstractString, args...) = Entity(Symbol(name), Symbol(class_name), args...)

# Old "ObjectClass" equivalent constructors.
EntityClass(name, entities::Vector{Entity}, args...) = EntityClass(name, Vector{Symbol}(), entities, args...)
function EntityClass(
    name,
    intact_dim_names,
    entities,
    vals::Dict{Entity,Dict{Symbol,ParameterValue}},
    args...
)
    new_vals = Dict{ObjectTupleLike,Dict{Symbol,ParameterValue}}(
        tuple(k) => v for (k,v) in vals
    )
    EntityClass(name, intact_dim_names, entities, new_vals, args...)
end
# Old "RelationshipClass" equivalent constructors.
function EntityClass(
    class_name,
    intact_dim_names,
    entities::Vector{T} where {T<:ObjectTupleLike},
    args...
)
    # We need to create new entities for the old relationships.
    entities = [
        Entity(
            _default_entity_name_from_tuple(ent_tuple),
            class_name,
            Vector{Entity}(),
            Vector{Entity}(),
            Vector{Entity}([ent_tuple...]),
            vcat(_recursive_byelement_list.([ent_tuple...])...)
        )
        for ent_tuple in entities
    ]
    EntityClass(class_name, intact_dim_names, entities, args...)
end

_default_entity_name_from_tuple(objtup::ObjectTupleLike) = Symbol(
    join(string.(getfield.(objtup, :name)), "__")
)

"""
    TimeSlice(start::DateTime, end_::DateTime)

Construct a `TimeSlice` with bounds given by `start` and `end_`.
"""
function TimeSlice(start::DateTime, end_::DateTime, blocks::Entity...; duration_unit=Hour)
    dur = Minute(end_ - start) / Minute(duration_unit(1))
    TimeSlice(start, end_, dur, blocks)
end

function TimeSeries(inds=[], vals=[]; ignore_year=false, repeat=false, merge_ok=false)
    TimeSeries(inds, vals, ignore_year, repeat; merge_ok=merge_ok)
end

Map(inds::Array{String,1}, vals::Array{V,1}) where {V} = Map(Symbol.(inds), vals)

Call(x, caller=nothing) = Call(nothing, [x], NamedTuple(), caller)
function Call(func::T, kwargs::Union{Iterators.Pairs,NamedTuple}, caller=nothing) where {T<:ParameterValue}
    Call(func, [], kwargs, caller)
end
Call(op::T, x, y) where {T<:Function} = Call(op, [x, y])
Call(op::T, args::Vector) where {T<:Function} = Call(op, args, NamedTuple(), nothing)
Call(other::Call) = other
