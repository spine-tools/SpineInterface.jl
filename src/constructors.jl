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

Object(name::Symbol, class_name) = Object(name, class_name, [], [])
Object(name::AbstractString, args...) = Object(Symbol(name), args...)
Object(name::AbstractString, class_name::AbstractString, args...) = Object(Symbol(name), Symbol(class_name), args...)
Object(name::Symbol) = Object(name::Symbol, nothing)

"""
    TimeSlice(start::DateTime, end_::DateTime)

Construct a `TimeSlice` with bounds given by `start` and `end_`.
"""
function TimeSlice(start::DateTime, end_::DateTime, blocks::Object...; duration_unit=Hour)
    dur = Minute(end_ - start) / Minute(duration_unit(1))
    TimeSlice(start, end_, dur, blocks)
end

function ObjectClass(name, objects::T, pvals=Dict(), defaults=Dict()) where T >: DataFrame
    ObjectClass(name, collect(objects), pvals, defaults)
end
function ObjectClass(name, objects::Vector, pvals=Dict(), defaults=Dict())
    class = ObjectClass(name, DataFrame(Dict(name => ObjectLike[])...), defaults)
    add_objects!(class, objects)
    add_object_parameter_values!(class, pvals)
end

function RelationshipClass(
    name, object_class_names, relationships::T, pvals=Dict(), defaults=Dict()
) where T >: DataFrame
    RelationshipClass(name, object_class_names, collect(relationships), pvals, defaults)
end
function RelationshipClass(name, object_class_names, relationships::Vector, pvals=Dict(), defaults=Dict())
    df = DataFrame(OrderedDict(name => ObjectLike[] for name in _fix_name_ambiguity(object_class_names))...)
    class = RelationshipClass(name, object_class_names, df, defaults)
    add_relationships!(class, relationships)
    add_relationship_parameter_values!(class, pvals)
end

function TimeSeries(inds=[], vals=[]; ignore_year=false, repeat=false, merge_ok=false)
    TimeSeries(inds, vals, ignore_year, repeat; merge_ok=merge_ok)
end

Map(inds::Array{String,1}, vals::Array{V,1}) where {V} = Map(Symbol.(inds), vals)
Map(inds::T, vals::Array{V,1}) where {T,V} = Map(collect(inds), vals)

Call(x, call_expr=nothing) = Call(nothing, [x], OrderedDict(), call_expr)
Call(func::T, kwargs::OrderedDict, call_expr=nothing) where {T<:ParameterValue} = Call(func, [], kwargs, call_expr)
function Call(func::T, kwargs::NamedTuple, call_expr=nothing) where {T<:ParameterValue}
    Call(func, OrderedDict(pairs(kwargs)), call_expr)
end
Call(op::T, x, y) where {T<:Function} = Call(op, [x, y])
Call(op::T, args::Vector) where {T<:Function} = Call(op, args, OrderedDict(), nothing)
Call(other::Call) = copy(other)
