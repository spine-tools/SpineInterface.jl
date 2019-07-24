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

function spinedb_parameter_handle(db_map::PyObject, object_dict::Dict, relationship_dict::Dict)
    parameter_dict = Dict()
    parameter_class_names = Dict()
    class_object_subset_dict = Dict{Symbol,Any}()
    object_parameter_value_dict =
        py"{(x.parameter_id, x.object_name): x.value for x in $db_map.object_parameter_value_list()}"
    relationship_parameter_value_dict =
        py"{(x.parameter_id, x.object_name_list): x.value for x in $db_map.relationship_parameter_value_list()}"
    value_list_dict = py"{x.id: x.value_list.split(',') for x in $db_map.wide_parameter_value_list_list()}"
    for parameter in py"[x._asdict() for x in $db_map.object_parameter_definition_list()]"
        parameter_name = parameter["parameter_name"]
        parameter_id = parameter["id"]
        object_class_name = parameter["object_class_name"]
        value_list_id = parameter["value_list_id"]
        if value_list_id != nothing
            d1 = get!(class_object_subset_dict, Symbol(object_class_name), Dict{Symbol,Any}())
            object_subset_dict = get!(d1, Symbol(parameter_name), Dict{Any,Any}())
            for value in value_list_dict[value_list_id]
                object_subset_dict[value] = Array{Object,1}()
            end
        end
        default_callable = try
            callable(db_api.from_database(parameter["default_value"]))
        catch e
            if e isa PyCall.PyError && e.T == db_api.ParameterValueFormatError
                rethrow(ErrorException("unable to parse default value of '$parameter_name': $(sprint(showerror, e))"))
            else
                rethrow()
            end
        end
        class_values = get!(parameter_dict, Symbol(parameter_name), Dict{Tuple,Any}())
        parameter_value_pairs = class_values[(Symbol(object_class_name),)] = Array{Pair,1}()
        for object_name in object_dict[object_class_name]
            value = get(object_parameter_value_dict, (parameter_id, object_name), nothing)
            callable_ = if value == nothing
                 default_callable
            else
                try
                    callable(db_api.from_database(value))
                catch e
                    if e isa PyCall.PyError && e.T == db_api.ParameterValueFormatError
                        rethrow(
                            ErrorException(
                                "unable to parse value of '$parameter_name' for '$object_name': $(sprint(showerror, e))"
                            )
                        )
                    else
                        rethrow()
                    end
                end
            end
            object = Object(object_name)
            push!(parameter_value_pairs, (object,) => callable_)
            # Add entry to class_object_subset_dict
            (value_list_id == nothing || value == nothing) && continue
            arr = get(object_subset_dict, value, nothing)
            if arr != nothing
                push!(arr, object)
            else
                @warn(
                    "the value of '$parameter_name' for '$object' is $value, which is not a listed value."
                )
            end
        end
    end
    for parameter in py"[x._asdict() for x in $db_map.relationship_parameter_definition_list()]"
        parameter_name = parameter["parameter_name"]
        parameter_id = parameter["id"]
        relationship_class_name = parameter["relationship_class_name"]
        object_class_name_list = parameter["object_class_name_list"]
        default_callable = try
            callable(db_api.from_database(parameter["default_value"]))
        catch e
            if e isa PyCall.PyError && e.T == db_api.ParameterValueFormatError
                rethrow(ErrorException("unable to parse default value of '$parameter_name': $(sprint(showerror, e))"))
            else
                rethrow()
            end
        end
        class_values = get!(parameter_dict, Symbol(parameter_name), Dict{Tuple,Any}())
        class_name = tuple(fix_name_ambiguity(Symbol.(split(object_class_name_list, ",")))...)
        alt_class_name = (Symbol(relationship_class_name),)
        # Add (class_name, alt_class_name) to the list of relationships classes between the same object classes
        d = get!(parameter_class_names, Symbol(parameter_name), Dict())
        push!(get!(d, sort([class_name...]), []), (class_name, alt_class_name))
        parameter_value_pairs = class_values[alt_class_name] = Array{Pair,1}()
        # Loop through all parameter values
        object_name_lists = relationship_dict[relationship_class_name]["object_name_lists"]
        for object_name_list in object_name_lists
            value = get(relationship_parameter_value_dict, (parameter_id, object_name_list), nothing)
            callable_ = if value == nothing
                 default_callable
            else
                try
                    callable(db_api.from_database(value))
                catch e
                    if e isa PyCall.PyError && e.T == db_api.ParameterValueFormatError
                        rethrow(
                            ErrorException(
                                string(
                                    "unable to parse value of '$parameter_name' for '$object_name_list': ",
                                    sprint(showerror, e)
                                )
                            )
                        )
                    else
                        rethrow()
                    end
                end
            end
            object_tuple = tuple(Object.(split(object_name_list, ","))...)
            push!(parameter_value_pairs, object_tuple => callable_)
        end
    end
    for (parameter_name, class_name_dict) in parameter_class_names
        for (sorted_class_name, class_name_tuples) in class_name_dict
            if length(class_name_tuples) > 1
                msg = "'$parameter_name' is defined on multiple relationship classes involving the same "
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
    for (parameter_name, class_values) in parameter_dict
        push!(keys, Symbol(parameter_name))
        push!(values, (Symbol(parameter_name), class_values))
    end
    NamedTuple{Tuple(keys)}(values), class_object_subset_dict
end

function spinedb_object_handle(db_map::PyObject, object_dict::Dict, class_object_subset_dict::Dict{Symbol,Any})
    keys = []
    values = []
    for (object_class_name, object_names) in object_dict
        object_subset_dict = get(class_object_subset_dict, Symbol(object_class_name), Dict())
        push!(keys, Symbol(object_class_name))
        push!(values, (Symbol(object_class_name), Object.(object_names), object_subset_dict))
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
        object_tuples = [NamedTuple{obj_cls_name_tuple}(y) for y in obj_tup_list]
        push!(keys, Symbol(rel_cls_name))
        push!(values, (Symbol(rel_cls_name), obj_cls_name_tuple, object_tuples))
    end
    NamedTuple{Tuple(keys)}(values)
end

function spinedb_handle(db_map::PyObject)
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
    param, class_object_subset_dict = spinedb_parameter_handle(db_map, object_dict, relationship_dict)
    obj_cls = spinedb_object_handle(db_map, object_dict, class_object_subset_dict)
    rel_cls = spinedb_relationship_handle(db_map, relationship_dict)
    obj_cls, rel_cls, param
end


"""
    using_spinedb(db_url::String; upgrade=false)

Take the Spine database at the given RFC-1738 `url`,
and export convenience *functors* named after each object class, relationship class,
and parameter in it. These functors can be used to retrieve specific contents in the db.

If `upgrade` is `true`, then the database at `url` is upgraded to the latest revision.

See [`ObjectClass()`](@ref), [`RelationshipClass()`](@ref), and [`Parameter()`](@ref) for details on
how to call the convenience functors.
"""
function using_spinedb(db_url::String, mod=@__MODULE__; upgrade=false)
    # Create DatabaseMapping object using Python spinedb_api
    try
        db_map = db_api.DatabaseMapping(db_url, upgrade=upgrade)
        using_spinedb(db_map, mod)
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
    using_spinedb(db_map::PyObject)

Create and export convenience *functors*
for accessing the given `db_map`,
which must be a `PyObject` as returned by `db_api.DiffDatabaseMapping`.

See [`Parameter()`](@ref), [`ObjectClass()`](@ref), and [`RelationshipClass()`](@ref) for details about
the convenience functors.
"""
function using_spinedb(db_map::PyObject, mod=@__MODULE__)
    @eval mod using SpineInterface
    obj_cls, rel_cls, param = spinedb_handle(db_map)
    for (name, value) in pairs(obj_cls)
        @eval mod begin
            $name = ObjectClass($value...)
            export $name
        end
    end
    for (name, value) in pairs(rel_cls)
        @eval mod begin
            $name = RelationshipClass($value...)
            export $name
        end
    end
    for (name, value) in pairs(param)
        @eval mod begin
            $name = Parameter($value...)
            export $name
        end
    end
end


function notusing_spinedb(db_url::String, mod=@__MODULE__; upgrade=false)
    # Create DatabaseMapping object using Python spinedb_api
    try
        db_map = db_api.DatabaseMapping(db_url, upgrade=upgrade)
        notusing_spinedb(db_map, mod)
    catch e
        if e isa PyCall.PyError && e.T == db_api.exception.SpineDBVersionError
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

function notusing_spinedb(db_map::PyObject, mod=@__MODULE__)
    obj_cls, rel_cls, param = spinedb_handle(db_map)
    for (name, value) in pairs(obj_cls)
        name in names(mod) || continue
        functor = getfield(mod, name)
        x, objects, object_subset_dict = value
        setdiff!(functor.objects, objects)
        for key in keys(functor.object_subset_dict)
            setdiff!(functor.object_subset_dict[key], objects)
        end
    end
    for (name, value) in pairs(rel_cls)
        name in names(mod) || continue
        functor = getfield(mod, name)
        x, obj_cls_name_tuple, object_tuples = value
        obj_cls_name_tuple == functor.obj_cls_name_tuple || continue
        setdiff!(functor.object_tuples, object_tuples)
        empty!(functor.cache)
    end
    for (name, value) in pairs(param)
        name in names(mod) || continue
        functor = getfield(mod, name)
        x, class_values = value
        for (class, values) in class_values
            functor_values = get(functor.class_values, class, nothing)
            functor_values === nothing && continue
            setdiff!(functor_values, values)
        end
    end
end
