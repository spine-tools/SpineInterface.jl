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

struct Anything
end

anything = Anything()

Base.intersect(s, ::Anything) = s
Base.show(io::IO, ::Anything) = print(io, "anything (really, nevermind)")

struct Object
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

"""
    Parameter

A function-like object that represents a Spine parameter.
The value of the parameter can be retrieved by calling this object
as described in [`(p::Parameter)(;object_class=object...)`](@ref)
"""
struct Parameter
    name::Symbol
    class_value_dict::Dict{Tuple,Any}
end

"""
    ObjectClass

A function-like object that represents a Spine object class.
The objects of the class can be retrieved by calling this object as
described in [`(o::ObjectClass)(;parameter=value...)`](@ref)
"""
struct ObjectClass
    name::Symbol
    object_names::Array{Object,1}
    object_subset_dict::Dict{Symbol,Any}
end

"""
    RelationshipClass

A function-like object that represents a Spine relationship class.
The relationships of the class can be retrieved by calling this object as described in
[`(r::RelationshipClass)(;_compact=true, object_class=object...)`](@ref)
"""
struct RelationshipClass
    name::Symbol
    obj_cls_name_tuple::Tuple
    obj_name_tuples::Array{NamedTuple,1}
    cache::Dict{Symbol,Any}
    RelationshipClass(n, o1, o2) = new(n, o1, o2, Dict{Symbol,Any}())
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
        parameter_value_tuples = p.class_value_dict[class_names]
        kwvalues = values(kwargs)
        object_names = Object.(Tuple([kwvalues[k] for k in class_names]))
        # Lookup value and bring it forward so it's found earlier in subsequent calls
        i = 1
        nobreak = true
        for (key, value) in parameter_value_tuples
            if key == object_names
                nobreak = false
                break
            end
            i += 1
        end
        nobreak && error("'$p' not specified for '$object_names'")
        key, value = parameter_value_tuples[i]
        if i > 1 && _optimize
            deleteat!(parameter_value_tuples, i)
            pushfirst!(parameter_value_tuples, (key, value))
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
            objs = []
            for v in ScalarValue.(val)
                obj = get(d, v, nothing)
                if obj == nothing
                    @warn("'$v' is not a listed value for '$par' as defined for class '$o'")
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
    (r::RelationshipClass)(;_indices=:compact, _default=nothing, object_class=object...)

The list of relationships of class `r`, optionally having `object_class=object`.
"""
function (r::RelationshipClass)(;_compact=true, _default=nothing, _optimize=true, kwargs...)
    new_kwargs = Dict()
    tail = []
    for (obj_cls, obj) in kwargs
        !(obj_cls in r.obj_cls_name_tuple) && continue
        # error("'$obj_cls' is not a member of '$r' (valid members are '$(join(r.obj_cls_name_tuple, "', '"))')")
        push!(tail, obj_cls)
        if obj != anything
            push!(new_kwargs, obj_cls => Object.(obj))
        end
    end
    head = if _compact
        Tuple(x for x in r.obj_cls_name_tuple if !(x in tail))
    else
        r.obj_cls_name_tuple
    end
    if isempty(head)
        []
    else
        if _optimize
            cls_indices_arr = []
            for (obj_cls, objs) in new_kwargs
                obj_indices_arr = []
                obj_cls_cache = get!(r.cache, obj_cls, Dict{Object,Array{Int64,1}}())
                for obj in objs
                    obj_indices = get(obj_cls_cache, obj, nothing)
                    if obj_indices == nothing
                        cond(x) = x[obj_cls] == obj
                        obj_indices = obj_cls_cache[obj] = findall(cond, r.obj_name_tuples)
                    end
                    push!(obj_indices_arr, obj_indices)
                end
                isempty(obj_indices_arr) || push!(cls_indices_arr, union(obj_indices_arr...))
            end
            if isempty(cls_indices_arr)
                result = r.obj_name_tuples
            else
                intersection = intersect(cls_indices_arr...)
                result = r.obj_name_tuples[intersection]
            end
        else
            result = [x for x in r.obj_name_tuples if all(x[k] in v for (k, v) in new_kwargs)]
        end
        if isempty(result) && _default != nothing
            _default
        elseif length(head) == 1
            unique(x[head...] for x in result)
        else
            unique(NamedTuple{head}([x[k] for k in head]) for x in result)
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
            object_subset_dict = get!(d1, Symbol(parameter_name), Dict{ScalarValue,Any}())
            for value in value_list_dict[value_list_id]
                object_subset_dict[ScalarValue(JSON.parse(value))] = Array{Object,1}()
            end
        end
        json_default_value = try
            JSON.parse(parameter["default_value"])
        catch e
            error("unable to parse default value of '$parameter_name': $(sprint(showerror, e))")
        end
        class_value_dict = get!(parameter_dict, Symbol(parameter_name), Dict{Tuple,Any}())
        parameter_value_tuples = class_value_dict[(Symbol(object_class_name),)] = Array{Tuple,1}()
        for object_name in object_dict[object_class_name]
            value = get(object_parameter_value_dict, (parameter_id, object_name), nothing)
            if value == nothing
                json_value = nothing
            else
                json_value = JSON.parse(value)
            end
            object = Object(object_name)
            new_value = try
                parse_value(json_value; default=json_default_value, tags...)
            catch e
                error("unable to parse value of '$parameter_name' for '$object_name': $(sprint(showerror, e))")
            end
            push!(parameter_value_tuples, ((object,), new_value))
            # Add entry to class_object_subset_dict
            (value_list_id == nothing || json_value == nothing) && continue
            arr = get(object_subset_dict, ScalarValue(json_value), nothing)
            if arr != nothing
                push!(arr, object)
            else
                @warn(
                    "the value of '$parameter_name' for '$object' is $json_value, "
                    * "which is not a listed value."
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
        class_value_dict = get!(parameter_dict, Symbol(parameter_name), Dict{Tuple,Any}())
        class_name = tuple(fix_name_ambiguity(Symbol.(split(object_class_name_list, ",")))...)
        alt_class_name = (Symbol(relationship_class_name),)
        # Add (class_name, alt_class_name) to the list of relationships classes between the same object classes
        d = get!(parameter_class_names, Symbol(parameter_name), Dict())
        push!(get!(d, sort([class_name...]), []), (class_name, alt_class_name))
        parameter_value_tuples = class_value_dict[alt_class_name] = Array{Tuple,1}()
        # Loop through all parameter values
        object_name_lists = relationship_dict[relationship_class_name]["object_name_lists"]
        for object_name_list in object_name_lists
            value = get(relationship_parameter_value_dict, (parameter_id, object_name_list), nothing)
            if value == nothing
                json_value = nothing
            else
                json_value = JSON.parse(value)
            end
            object_tuple = tuple(Object.(split(object_name_list, ","))...)
            new_value = try
                parse_value(json_value; default=json_default_value, tags...)
            catch e
                error(
                    "unable to parse value of '$parameter_name' for '$object_tuple': "
                    * "$(sprint(showerror, e))"
                )
            end
            push!(parameter_value_tuples, (object_tuple, new_value))
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
    for (parameter_name, class_value_dict) in parameter_dict
        push!(keys, Symbol(parameter_name))
        push!(values, Parameter(Symbol(parameter_name), class_value_dict))
    end
    NamedTuple{Tuple(keys)}(values), class_object_subset_dict
end

function spinedb_object_handle(db_map::PyObject, object_dict::Dict, class_object_subset_dict::Dict{Symbol,Any})
    keys = []
    values = []
    for (object_class_name, object_names) in object_dict
        object_subset_dict = get(class_object_subset_dict, Symbol(object_class_name), Dict())
        push!(keys, Symbol(object_class_name))
        push!(values, ObjectClass(Symbol(object_class_name), Object.(object_names), object_subset_dict))
    end
    NamedTuple{Tuple(keys)}(values)
end

function spinedb_relationship_handle(db_map::PyObject, relationship_dict::Dict)
    keys = []
    values = []
    for (rel_cls_name, rel_cls) in relationship_dict
        obj_cls_name_list = Symbol.(split(rel_cls["object_class_name_list"], ","))
        obj_tup_list = [Object.(split(y, ",")) for y in rel_cls["object_name_lists"]]
        obj_cls_name_tuple = Tuple(fix_name_ambiguity(obj_cls_name_list))
        obj_tuples = [NamedTuple{obj_cls_name_tuple}(y) for y in obj_tup_list]
        push!(keys, Symbol(rel_cls_name))
        push!(values, RelationshipClass(Symbol(rel_cls_name), obj_cls_name_tuple, obj_tuples))
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
    db_handle = merge(p, o, r)
    for (name, value) in pairs(db_handle)
        @eval begin
            $name = $value
            export $name
        end
    end
end


function notusing_spinedb(db_url::String; upgrade=false)
    # Create DatabaseMapping object using Python spinedb_api
    try
        db_map = db_api.DatabaseMapping(db_url, upgrade=upgrade)
        notusing_spinedb(db_map)
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

function notusing_spinedb(db_map::PyObject)
    obj_cls_names = py"[x.name for x in $db_map.object_class_list()]"
    rel_cls_names = py"[x.name for x in $db_map.wide_relationship_class_list()]"
    par_names = py"[x.name for x in $db_map.parameter_definition_list()]"
    for name in [obj_cls_names; rel_cls_names; par_names]
        @eval $(Symbol(name)) = nothing
    end
end
