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

The singleton instance of type [`Anything`](@ref), used for passing *catchall* filters
to [`ObjectClass()`](@ref), and [`RelationshipClass()`](@ref), and [`Parameter()`](@ref).

# Example

TODO
"""
anything = Anything()

Base.intersect(s, ::Anything) = s
Base.show(io::IO, ::Anything) = print(io, "anything (aka all of them)")


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
end

Object(name::AbstractString) = Object(Symbol(name))
Object(::Anything) = anything
Object(other::Object) = other

# Iterate single `Object` as collection
Base.iterate(o::Object) = iterate((o,))
Base.iterate(o::Object, state::T) where T = iterate((o,), state)
Base.length(o::Object) = 1
# Compare `Object`s
Base.isless(o1::Object, o2::Object) = o1.name < o2.name

struct Parameter
    name::Symbol
    class_value_dict::Dict{Tuple,Any}
end

struct ObjectClass
    name::Symbol
    object_names::Array{Object,1}
    object_subset_dict::Dict{Symbol,Any}
end

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
    (p::Parameter)(;<keyword arguments>)

The value of parameter `p` for the object or relationship specified by keyword arguments
of the form `object_class=:object`.

# Additional arguments

- `i::Int64`: a specific index to retrieve in case of an array value (ignored otherwise).
- `k::String`: a specific key to retrieve in case of a dictionary value (ignored otherwise).
- `t::TimeSlice`: a specific time-index to retrieve in case of a time-varying value (ignored otherwise).


# Example

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
    (oc::ObjectClass)(;<keyword arguments>)

An `Array` of [`Object`](@ref) instances corresponding to the objects in class `oc`.

Keyword arguments of the form `parameter_name=value` act as filtering conditions.

# Example

```jldoctest
julia> using SpineInterface;

julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");

julia> using_spinedb(url)

julia> node()
5-element Array{Object,1}:
 Nimes
 Sthlm
 Leuven
 Espoo
 Dublin

julia> commodity(state_of_matter=:gas)
1-element Array{Any,1}:
 wind

```
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
    (rc::RelationshipClass)(;<keyword arguments>)

An `Array` of [`Object`](@ref) tuples corresponding to the relationships of class `rc`.

Keyword arguments of the form `object_class=:object` act as filtering conditions.

# Additional arguments

- `_compact::Bool=true`: whether or not filtered objects should be skipped in the resulting tuple.
- `_default=[]`: the default value to return in case no relationship meets the filter.

```jldoctest
julia> using SpineInterface;

julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");

julia> using_spinedb(url)

julia> node__commodity()
5-element Array{NamedTuple{(:node, :commodity),Tuple{Object,Object}},1}:
 (node = Dublin, commodity = wind)
 (node = Espoo, commodity = wind)
 (node = Leuven, commodity = wind)
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=:water)
2-element Array{Object,1}:
 Nimes
 Sthlm

julia> node__commodity(commodity=:water, _compact=false)
2-element Array{NamedTuple{(:node, :commodity),Tuple{Object,Object}},1}:
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=:gas, _default=:nogas)
:nogas

```
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
