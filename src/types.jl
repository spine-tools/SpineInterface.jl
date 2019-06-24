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

struct SpineDBParseError{T} <: Exception where T <: Exception
    original_exception::T
    parameter_name::String
    object_name
end

SpineDBParseError(orig, par) = SpineDBParseError(orig, par, nothing)

function Base.showerror(io::IO, e::SpineDBParseError)
    if e.object_name != nothing
        print(
            io,
            "unable to parse value of '$(e.parameter_name)' for '$(e.object_name)': ",
            sprint(showerror, e.original_exception)
        )
    else
        print(
            io,
            "unable to parse default value of '$(e.parameter_name)': ",
            sprint(showerror, e.original_exception)
        )
    end
end


"""
    Anything

A type with not fields that is the type of [`anything`](@ref).
"""
struct Anything
end

"""
    anything

The singleton instance of type [`Anything`](@ref), used for creating filters
"""
anything = Anything()

Base.intersect(s, ::Anything) = s
Base.show(io::IO, ::Anything) = print(io, "anything (aka all of them)")


"""
    ObjectLike

Supertype for [`Object`](@ref) and all types that want to use the same interface.
"""
abstract type ObjectLike end

"""
    Object

An object in a Spine db.
"""
struct Object <: ObjectLike
    name::Symbol
end

"""
    Object(name)

Construct an `Object` with the given name which can be either a `String` or a `Symbol`.
"""
Object(name::AbstractString) = Object(Symbol(name))
Object(::Anything) = anything
Object(other::Object) = other

# Iterate single `Object` as collection
Base.iterate(o::Object) = iterate((o,))
Base.iterate(o::Object, state::T) where T = iterate((o,), state)
Base.length(o::Object) = 1
# Compare `Object`s
Base.isless(o1::Object, o2::Object) = o1.name < o2.name

"""
    Parameter

A functor for accessing a parameter in a Spine db.
"""
struct Parameter
    name::Symbol
    class_value_dict::Dict{Tuple,Any}
end

"""
    ObjectClass

A functor for accessing an object class in a Spine db.
"""
struct ObjectClass
    name::Symbol
    object_names::Array{Object,1}
    object_subset_dict::Dict{Symbol,Any}
end

"""
    RelationshipClass

A functor for accessing a relationship class in a Spine db.
"""
struct RelationshipClass{N,K,V}
    name::Symbol
    obj_cls_name_tuple::NTuple{N,Symbol}
    obj_name_tuples::Array{NamedTuple{K,V},1}
    obj_type_dict::Dict{Symbol,Type}
    cache::Array{Pair,1}
end

function RelationshipClass(
        n,
        oc::NTuple{N,Symbol},
        os::Array{NamedTuple{K,V},1}
    ) where {N,K,V<:Tuple}
    K == oc || error("$K and $oc do not match")
    d = Dict(zip(K, V.parameters))
    RelationshipClass{N,K,V}(n, oc, sort(os), d, Array{Pair,1}())
end

function RelationshipClass(
        n,
        oc::NTuple{N,Symbol},
        os::Array{NamedTuple{K,V} where V<:Tuple,1}
    ) where {N,K}
    K == oc || error("$K and $oc do not match")
    d = Dict(k => Object for k in K)
    V = NTuple{N,Object}
    RelationshipClass{N,K,V}(n, oc, sort(os), d, Array{Pair,1}())
end

Base.show(io::IO, p::Parameter) = print(io, p.name)
Base.show(io::IO, oc::ObjectClass) = print(io, oc.name)
Base.show(io::IO, rc::RelationshipClass) = print(io, rc.name)
Base.show(io::IO, o::Object) = print(io, o.name)

"""
    (p::Parameter)(;object_class=object..., extra_kwargs...)

The value of parameter `p` for the given combination of `object_class=object` tuples.
NOTE: Additional keyword arguments are used to call the value.
"""
function (p::Parameter)(;_optimize=true, kwargs...)
    if length(kwargs) == 0
        # Return dict if kwargs is empty
        p.class_value_dict
    else
        kwkeys = keys(kwargs)
        class_names = getsubkey(p.class_value_dict, kwkeys, nothing)
        class_names == nothing && error("can't find a definition of '$p' for '$kwkeys'")
        parameter_value_pairs = p.class_value_dict[class_names]
        kwvalues = values(kwargs)
        object_names = Object.(Tuple([kwvalues[k] for k in class_names]))
        value = pull!(parameter_value_pairs, object_names, nothing; _optimize=_optimize)
        value === nothing && error("'$p' not specified for '$object_names'")
        extra_kwargs = Dict(k => v for (k, v) in kwargs if !(k in class_names))
        value(;extra_kwargs...)
    end
end

"""
    (oc::ObjectClass)(;kwargs...)

A list of [`Object`](@ref) instances corresponding to objects in class `oc`.

`kwargs` given as `parameter_name=value` filter the result
so that it only contains objects with the given value(s) for the given parameter(s).
"""
function (oc::ObjectClass)(;kwargs...)
    if length(kwargs) == 0
        oc.object_names
    else
        # Return the object subset at the intersection of all kwargs
        object_subset = []
        for (par, val) in kwargs
            !haskey(oc.object_subset_dict, par) && error("'$par' is not a list-parameter for '$oc'")
            d = oc.object_subset_dict[par]
            objs = []
            for v in ScalarValue.(val)
                obj = get(d, v, nothing)
                if obj == nothing
                    @warn("'$v' is not a listed value for '$par' as defined for class '$oc'")
                else
                    append!(objs, obj)
                end
            end
            if isempty(object_subset)
                object_subset = objs
            else
                object_subset = [x for x in object_subset if x in objs]
            end
        end
        object_subset
    end
end

"""
    (rc::RelationshipClass)(;_compact=true, _default=[], _optimize=true, kwargs...)

A list of tuples of [`Object`](@ref) instances corresponding to relationships of class `rc`.

`kwargs` given as `object_class_name=object` filter the result
so it only contains relationships with the given object in the given class.
"""
function (rc::RelationshipClass)(;_compact=true, _default=[], _optimize=true, kwargs...)
    new_kwargs = Dict()
    tail = []
    for (obj_cls, obj) in kwargs
        !(obj_cls in rc.obj_cls_name_tuple) && error(
            "'$obj_cls' is not a member of '$rc' (valid members are '$(join(rc.obj_cls_name_tuple, "', '"))')"
        )
        push!(tail, obj_cls)
        if obj != anything
            push!(new_kwargs, obj_cls => rc.obj_type_dict[obj_cls].(obj))
        end
    end
    head = if _compact
        Tuple(x for x in rc.obj_cls_name_tuple if !(x in tail))
    else
        rc.obj_cls_name_tuple
    end
    result = if isempty(head)
        []
    elseif _optimize
        indices = pull!(rc.cache, new_kwargs, nothing; _optimize=true)
        if indices === nothing
            cond(x) = all(x[k] in v for (k, v) in new_kwargs)
            indices = findall(cond, rc.obj_name_tuples)
            pushfirst!(rc.cache, new_kwargs => indices)
        end
        rc.obj_name_tuples[indices]
    else
        [x for x in rc.obj_name_tuples if all(x[k] in v for (k, v) in new_kwargs)]
    end
    if isempty(result)
        _default
    elseif head == rc.obj_cls_name_tuple
        result
    elseif length(head) == 1
        unique_sorted(x[head...] for x in result)
    else
        unique_sorted(NamedTuple{head}([x[k] for k in head]) for x in result)
    end
end
