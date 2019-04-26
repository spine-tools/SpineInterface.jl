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
    Parameter

A function-like object that represents a Spine parameter. The value of the parameter
is retrieved by calling [`(p::Parameter)(;object_class=object...)`](@ref)
"""
struct Parameter
    name::Symbol
    class_parameter_value_dict::Dict{Tuple,Any}
    cache_keys::Array{Any,1}
    cache_values::Array{Any,1}
    cache_size::Int
    Parameter(n, d) = new(n, d, [], [], maximum(length(v) for v in values(d)))
end

"""
    ObjectClass

A function-like object that represents a Spine object class. The objects of the class
are retrieved by calling [`(p::Parameter)(;object_class=object...)`](@ref)
"""
struct ObjectClass
    name::Symbol
    object_names::Array{Symbol,1}
    object_subset_dict::Dict{Symbol,Any}
end

"""
    RelationshipClass

A function-like object that represents a Spine relationship class. The relationships of the class
are retrieved by calling [`(p::Parameter)(;object_class=object...)`](@ref)
"""
struct RelationshipClass
    name::Symbol
    obj_cls_name_tuple::Tuple
    obj_name_tuples::Array{NamedTuple,1}
end

Base.show(io::IO, p::Parameter) = print(io, p.name)
Base.show(io::IO, o::ObjectClass) = print(io, o.name)
Base.show(io::IO, r::RelationshipClass) = print(io, r.name)


function cachevalue(p::Parameter, key::T) where T
    for (i, k) in enumerate(p.cache_keys)
        k == key && return p.cache_values[i]
    end
    nothing
end

function cachepush!(p::Parameter, key, value)
    pushfirst!(p.cache_keys, key)
    pushfirst!(p.cache_values, value)
    if length(p.cache_keys) > p.cache_size
        p.cache_keys = p.cache_keys[1:p.cache_size]
        p.cache_values = p.cache_values[1:p.cache_size]
    end
    value
end

"""
    (p::Parameter)(;object_class=object...)

The value of parameter `p` for the given combination of `object_class=object` tuples.
"""
function (p::Parameter)(;kwargs...)
    if length(kwargs) == 0
        # Return dict if kwargs is empty
        p.class_parameter_value_dict
    else
        kwkeys = keys(kwargs)
        class_names = getsubkey(p.class_parameter_value_dict, kwkeys, nothing)
        class_names == nothing && error("can't find a definition of '$p' for '$kwkeys'")
        kwvalues = values(kwargs)
        object_names = Tuple([kwvalues[k] for k in class_names])
        cachekey = (class_names, object_names)
        value = cachevalue(p, cachekey)
        if value == nothing
            parameter_value_dict = p.class_parameter_value_dict[class_names]
            haskey(parameter_value_dict, object_names) || error("'$p' not specified for '$object_names'")
            value = parameter_value_dict[object_names]
            cachepush!(p, cachekey, value)
        end
        extra_kwargs = Dict(k => v for (k, v) in kwargs if !(k in class_names))
        value(;extra_kwargs...)
    end
end

"""
    (o::ObjectClass)(;parameter=value...)

The list of objects of class `o`, optionally having `parameter=value`.
"""
function (o::ObjectClass)(;kwargs...)
    if length(kwargs) == 0
        o.object_names
    else
        # Return the object subset at the intersection of all kwargs
        object_subset = []
        for (par, val) in kwargs
            !haskey(o.object_subset_dict, par) && error("'$par' is not a list-parameter for '$o'")
            d = o.object_subset_dict[par]
            !haskey(d, val) && error("'$val' is not a listed value for '$par' as defined for class '$o'")
            if isempty(object_subset)
                object_subset = d[val]
            else
                object_subset = [x for x in object_subset if x in d[val]]
            end
        end
        object_subset
    end
end

"""
    (r::RelationshipClass)(;_compact=true, object_class=object...)

The list of relationships of class `r`, optionally having `object_class=object`.
"""
function (r::RelationshipClass)(;_compact=true, kwargs...)
    new_kwargs = Dict()
    filtered_classes = []
    for (obj_cls, obj) in kwargs
        !(obj_cls in r.obj_cls_name_tuple) && error(
            "'$obj_cls' is not a member of '$r' (valid members are '$(join(r.obj_cls_name_tuple, "', '"))')"
        )
        push!(filtered_classes, obj_cls)
        if obj != :any
            applicable(iterate, obj) || (obj = (obj,))
            push!(new_kwargs, obj_cls => obj)
        end
    end
    result_classes = if _compact
        Tuple(x for x in r.obj_cls_name_tuple if !(x in filtered_classes))
    else
        r.obj_cls_name_tuple
    end
    if isempty(result_classes)
        []
    else
        result = [x for x in r.obj_name_tuples if all(x[k] in v for (k, v) in new_kwargs)]
        if length(result_classes) == 1
            unique(x[result_classes...] for x in result)
        else
            unique(NamedTuple{result_classes}([x[k] for k in result_classes]) for x in result)
        end
    end
end


function spinedb_parameter_handle(db_map::PyObject, object_dict::Dict, relationship_dict::Dict, parse_value)
    parameter_dict = Dict()
    parameter_class_names = Dict()
    class_object_subset_dict = Dict{Symbol,Any}()
    object_parameter_value_dict =
        py"{(x.parameter_id, x.object_name): x.value for x in $db_map.object_parameter_value_list()}"
    relationship_parameter_value_dict =
        py"{(x.parameter_id, x.object_name_list): x.value for x in $db_map.relationship_parameter_value_list()}"
    value_list_dict = py"{x.id: x.value_list.split(',') for x in $db_map.wide_parameter_value_list_list()}"
    for parameter in py"[x._asdict() for x in $db_map.object_parameter_list()]"
        parameter_name = parameter["parameter_name"]
        parameter_id = parameter["id"]
        object_class_name = parameter["object_class_name"]
        tag_list = parameter["parameter_tag_list"]
        value_list_id = parameter["value_list_id"]
        tags = if tag_list isa String
            Dict(Symbol(x) => true for x in split(tag_list, ","))
        else
            Dict()
        end
        if value_list_id != nothing
            d1 = get!(class_object_subset_dict, Symbol(object_class_name), Dict{Symbol,Any}())
            object_subset_dict = get!(d1, Symbol(parameter_name), Dict{Symbol,Any}())
            for value in value_list_dict[value_list_id]
                object_subset_dict[Symbol(JSON.parse(value))] = Array{Symbol,1}()
            end
        end
        json_default_value = try
            JSON.parse(parameter["default_value"])
        catch e
            error("unable to parse default value of '$parameter_name': $(sprint(showerror, e))")
        end
        class_parameter_value_dict = get!(parameter_dict, Symbol(parameter_name), Dict{Tuple,Any}())
        parameter_value_dict = class_parameter_value_dict[(Symbol(object_class_name),)] = Dict{Tuple,Any}()
        for object_name in object_dict[object_class_name]
            value = get(object_parameter_value_dict, (parameter_id, object_name), nothing)
            if value == nothing
                json_value = nothing
            else
                json_value = JSON.parse(value)
            end
            symbol_object_name = Symbol(object_name)
            new_value = try
                parse_value(json_value; default=json_default_value, tags...)
            catch e
                error("unable to parse value of '$parameter_name' for '$object_name': $(sprint(showerror, e))")
            end
            parameter_value_dict[(symbol_object_name,)] = new_value
            # Add entry to class_object_subset_dict
            value_list_id == nothing && continue
            if haskey(object_subset_dict, Symbol(json_value))
                arr = object_subset_dict[Symbol(json_value)]
                push!(arr, symbol_object_name)
            else
                @warn string(
                    "the value of '$parameter_name' for '$symbol_object_name' is $json_value",
                    "which is not a listed value."
                )
            end
        end
    end
    relationship_parameter_list = py"[x._asdict() for x in $db_map.relationship_parameter_list()]"
    for parameter in relationship_parameter_list
        parameter_name = parameter["parameter_name"]
        parameter_id = parameter["id"]
        relationship_class_name = parameter["relationship_class_name"]
        object_class_name_list = parameter["object_class_name_list"]
        tag_list = parameter["parameter_tag_list"]
        tags = if tag_list isa String
            Dict(Symbol(x) => true for x in split(tag_list, ","))
        else
            Dict()
        end
        json_default_value = try
            JSON.parse(parameter["default_value"])
        catch e
            error("unable to parse default value of '$parameter_name': $(sprint(showerror, e))")
        end
        class_parameter_value_dict = get!(parameter_dict, Symbol(parameter_name), Dict{Tuple,Any}())
        class_name = tuple(fix_name_ambiguity(Symbol.(split(object_class_name_list, ",")))...)
        alt_class_name = (Symbol(relationship_class_name),)
        # Add (class_name, alt_class_name) to the list of relationships classes between the same object classes
        d = get!(parameter_class_names, Symbol(parameter_name), Dict())
        push!(get!(d, sort([class_name...]), []), (class_name, alt_class_name))
        parameter_value_dict = class_parameter_value_dict[alt_class_name] = Dict{Tuple,Any}()
        # Loop through all parameter values
        object_name_lists = relationship_dict[relationship_class_name]["object_name_lists"]
        for object_name_list in object_name_lists
            value = get(relationship_parameter_value_dict, (parameter_id, object_name_list), nothing)
            if value == nothing
                json_value = nothing
            else
                json_value = JSON.parse(value)
            end
            symbol_object_name_list = tuple(Symbol.(split(object_name_list, ","))...)
            new_value = try
                parse_value(json_value; default=json_default_value, tags...)
            catch e
                error(
                    "unable to parse value of '$parameter_name' for '$symbol_object_name_list': "
                    * "$(sprint(showerror, e))"
                )
            end
            parameter_value_dict[symbol_object_name_list] = new_value
        end
    end
    for (parameter_name, class_name_dict) in parameter_class_names
        for (sorted_class_name, class_name_tuples) in class_name_dict
            if length(class_name_tuples) > 1
                msg = "'$parameter_name' is defined on multiple relationship classes among the same "
                msg *= "object classes '$(join(sorted_class_name, "', '"))'"
                msg *= " - use, e.g., `$parameter_name($(last(class_name_tuples[1])[1])=...)` to access it"
                @warn msg
            else
                # Replace alt_class_name with class_name, since there's no ambiguity
                class_name, alt_class_name = class_name_tuples[1]
                d = parameter_dict[parameter_name]
                d[class_name] = pop!(d, alt_class_name)
            end
        end
    end
    keys = []
    values = []
    for (parameter_name, class_parameter_value_dict) in parameter_dict
        push!(keys, Symbol(parameter_name))
        push!(values, Parameter(Symbol(parameter_name), class_parameter_value_dict))
    end
    NamedTuple{Tuple(keys)}(values), class_object_subset_dict
end

function spinedb_object_handle(db_map::PyObject, object_dict::Dict, class_object_subset_dict::Dict{Symbol,Any})
    keys = []
    values = []
    for (object_class_name, object_names) in object_dict
        object_subset_dict = get(class_object_subset_dict, Symbol(object_class_name), Dict())
        push!(keys, Symbol(object_class_name))
        push!(values, ObjectClass(Symbol(object_class_name), Symbol.(object_names), object_subset_dict))
    end
    NamedTuple{Tuple(keys)}(values)
end

function spinedb_relationship_handle(db_map::PyObject, relationship_dict::Dict)
    keys = []
    values = []
    for (rel_cls_name, rel_cls) in relationship_dict
        obj_cls_name_list = Symbol.(split(rel_cls["object_class_name_list"], ","))
        obj_name_lists = [Symbol.(split(y, ",")) for y in rel_cls["object_name_lists"]]
        obj_cls_name_tuple = Tuple(fix_name_ambiguity(obj_cls_name_list))
        obj_name_tuples = [NamedTuple{obj_cls_name_tuple}(y) for y in obj_name_lists]
        push!(keys, Symbol(rel_cls_name))
        push!(values, RelationshipClass(Symbol(rel_cls_name), obj_cls_name_tuple, obj_name_tuples))
    end
    NamedTuple{Tuple(keys)}(values)
end


"""
    using_spinedb(db_url::String; parse_value=parse_value, upgrade=false)

Create and export convenience function-like objects to access the database at the given
[sqlalchemy url](http://docs.sqlalchemy.org/en/latest/core/engines.html#database-urls).
These objects are of type [`Parameter`](@ref), [`ObjectClass`](@ref), and [`RelationshipClass`](@ref).

The argument `parse_value` is a function, for mapping `(db_value; default, tags...)` into a callable, where
- `db_value` is the value retrieved from the database and parsed using `JSON.parse`
- `default` is the default value retrieved from the database and parsed using `JSON.parse`
- `tags` is a list of tags.
"""
function using_spinedb(db_url::String; parse_value=parse_value, upgrade=false)
    # Create DatabaseMapping object using Python spinedb_api
    try
        db_map = db_api.DatabaseMapping(db_url, upgrade=upgrade)
        using_spinedb(db_map; parse_value=parse_value)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBVersionError)
            error(
"""
The database at '$db_url' is from an older version of Spine
and needs to be upgraded in order to be used with the current version.

You can upgrade it by running `checkout_spinedb(db_url; upgrade=true)`.

WARNING: After the upgrade, the database may no longer be used
with previous versions of Spine.
"""
            )
        else
            rethrow()
        end
    end
end


"""
    using_spinedb(db_map::PyObject; parse_value=parse_value)

Create and export convenience function-like objects to access the given `db_map`,
which must be an instance of `DiffDatabaseMapping` as
provided by [`spinedb_api`](https://github.com/Spine-project/Spine-Database-API).
See [`using_spinedb(db_url::String; parse_value=parse_value, upgrade=false)`](@ref)
for more details.
"""
function using_spinedb(db_map::PyObject; parse_value=parse_value)
    py"""object_dict = {
        x.name: [y.name for y in $db_map.object_list(class_id=x.id)] for x in $db_map.object_class_list()
    }
    relationship_dict = {
        x.name: {
            'object_class_name_list': x.object_class_name_list,
            'object_name_lists': [y.object_name_list for y in $db_map.wide_relationship_list(class_id=x.id)]
        } for x in $db_map.wide_relationship_class_list()
    }"""
    object_dict = py"object_dict"
    relationship_dict = py"relationship_dict"
    p, class_object_subset_dict = spinedb_parameter_handle(db_map, object_dict, relationship_dict, parse_value)
    o = spinedb_object_handle(db_map, object_dict, class_object_subset_dict)
    r = spinedb_relationship_handle(db_map, relationship_dict)
    db = merge(p, o, r)
    for (name, value) in pairs(db)
        eval(:($name = $value))
        eval(:(export $name))
    end
end
