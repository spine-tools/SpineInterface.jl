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

function spinedb_handle(db_map::PyObject)
    obj_cls_material = Dict{Tuple{Symbol,NamedTuple},Any}()
    rel_cls_material = Dict{Tuple{Symbol,NamedTuple,Tuple},Any}()
    param_material = Dict{Symbol,Vector{Symbol}}()
    # Query db
    all_object_classes = py"[x._asdict() for x in $db_map.query($db_map.object_class_sq)]"
    all_relationship_classes = py"[x._asdict() for x in $db_map.query($db_map.wide_relationship_class_sq)]"
    all_objects = py"[x._asdict() for x in $db_map.query($db_map.object_sq)]"
    all_relationships = py"[x._asdict() for x in $db_map.query($db_map.wide_relationship_sq)]"
    all_parameters = py"[x._asdict() for x in $db_map.query($db_map.parameter_definition_sq)]"
    all_param_values = py"[x._asdict() for x in $db_map.query($db_map.parameter_value_sq)]"
    object_dict = Dict()
    relationship_dict = Dict()
    obj_param_dict = Dict()
    rel_param_dict = Dict()
    obj_param_val_dict = Dict()
    rel_param_val_dict = Dict()
    # Compose
    for obj in all_objects
        push!(get!(object_dict, obj["class_id"], Dict[]), obj)
    end
    for rel in all_relationships
        push!(get!(relationship_dict, rel["class_id"], Dict[]), rel)
    end
    for param in all_parameters
        if param["object_class_id"] != nothing
            push!(get!(obj_param_dict, param["object_class_id"], Dict[]), param)
        elseif param["relationship_class_id"] != nothing
            push!(get!(rel_param_dict, param["relationship_class_id"], Dict[]), param)
        end
    end
    for param_val in all_param_values
        parameter_id = param_val["parameter_definition_id"]
        if param_val["object_id"] != nothing
            obj_param_val_dict[parameter_id, param_val["object_id"]] = param_val["value"]
        elseif param_val["relationship_id"] != nothing
            rel_param_val_dict[parameter_id, param_val["relationship_id"]] = param_val["value"]
        end
    end
    # Get material
    # Loop object classes
    for object_class in all_object_classes
        object_class_name = object_class["name"]
        object_class_id = object_class["id"]
        parameters = get(obj_param_dict, object_class_id, ())
        # Get default values
        default_values_d = Dict()
        for parameter in parameters
            parameter_name = parameter["name"]
            parameter_id = parameter["id"]
            push!(get!(param_material, Symbol(parameter_name), Symbol[]), Symbol(object_class_name))
            default_value = parameter["default_value"]
            default_values_d[Symbol(parameter_name)] = try
                callable(db_api.from_database(default_value))
            catch e
                if e isa PyCall.PyError && e.T == db_api.ParameterValueFormatError
                    rethrow(
                        ErrorException("unable to parse default value of '$parameter_name': $(sprint(showerror, e))")
                    )
                else
                    rethrow()
                end
            end
        end
        # Get objects and their values
        objects = obj_cls_material[Symbol(object_class_name), (;default_values_d...)] = Tuple{Object,NamedTuple}[]
        for object in get(object_dict, object_class_id, ())
            object_name = object["name"]
            object_id = object["id"]
            values_d = Dict()
            for parameter in parameters
                parameter_name = parameter["name"]
                parameter_id = parameter["id"]
                value = get(obj_param_val_dict, (parameter_id, object_id), nothing)
                value === nothing && continue
                values_d[Symbol(parameter_name)] = try
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
            push!(objects, (Object(object_name), (;values_d...)))
        end
    end
    # Loop relationship classes
    for relationship_class in all_relationship_classes
        rel_cls_name = relationship_class["name"]
        obj_cls_name_lst = fix_name_ambiguity(split(relationship_class["object_class_name_list"], ","))
        obj_cls_name_tup = Tuple(Symbol.(obj_cls_name_lst))
        rel_cls_id = relationship_class["id"]
        parameters = get(rel_param_dict, rel_cls_id, ())
        # Get default values
        default_values_d = Dict()
        for parameter in parameters
            parameter_name = parameter["name"]
            parameter_id = parameter["id"]
            push!(get!(param_material, Symbol(parameter_name), Symbol[]), Symbol(rel_cls_name))
            default_value = parameter["default_value"]
            default_values_d[Symbol(parameter_name)] = try
                callable(db_api.from_database(default_value))
            catch e
                if e isa PyCall.PyError && e.T == db_api.ParameterValueFormatError
                    rethrow(
                        ErrorException("unable to parse default value of '$parameter_name': $(sprint(showerror, e))")
                    )
                else
                    rethrow()
                end
            end
        end
        # Get relationships and their values
        rel_cls_key = (Symbol(rel_cls_name), (;default_values_d...), obj_cls_name_tup)
        relationships = rel_cls_material[rel_cls_key] = Tuple{NamedTuple,NamedTuple}[]
        for relationship in get(relationship_dict, rel_cls_id, ())
            object_name_list = split(relationship["object_name_list"], ",")
            relationship_id = relationship["id"]
            values_d = Dict()
            for parameter in parameters
                parameter_name = parameter["name"]
                parameter_id = parameter["id"]
                value = get(rel_param_val_dict, (parameter_id, relationship_id), nothing)
                value === nothing && continue
                values_d[Symbol(parameter_name)] = try
                    callable(db_api.from_database(value))
                catch e
                    if e isa PyCall.PyError && e.T == db_api.ParameterValueFormatError
                        rethrow(
                            ErrorException(
                                "unable to parse value of '$parameter_name' for '$object_name_list': "
                                * "$(sprint(showerror, e))"
                            )
                        )
                    else
                        rethrow()
                    end
                end
            end
            push!(relationships, (NamedTuple{obj_cls_name_tup}(Object.(object_name_list)), (;values_d...)))
        end
    end
    # Handlers
    obj_cls_handler = Dict(
        name => (name, default_values, objects) for ((name, default_values), objects) in obj_cls_material
    )
    rel_cls_handler = Dict(
        name => (name, default_values, obj_cls_name_tup, relationships)
        for ((name, default_values, obj_cls_name_tup), relationships) in rel_cls_material
    )
    param_handler = Dict(name => (name, classes) for (name, classes) in param_material)
    obj_cls_handler, rel_cls_handler, param_handler
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

Take the given `db_map` (a `spinedb_api.DiffDatabaseMapping` object),
and export convenience *functors* named after each object class, relationship class,
and parameter in it. These functors can be used to retrieve specific contents in the db.

If `upgrade` is `true`, then the database at `url` is upgraded to the latest revision.

See [`ObjectClass()`](@ref), [`RelationshipClass()`](@ref), and [`Parameter()`](@ref) for details on
how to call the convenience functors.
"""
function using_spinedb(db_map::PyObject, mod=@__MODULE__)
    @eval mod using SpineInterface
    obj_cls_handler, rel_cls_handler, param_handler = spinedb_handle(db_map)
    for (name, value) in obj_cls_handler
        @eval mod begin
            $name = ObjectClass($value...)
            export $name
        end
    end
    for (name, value) in rel_cls_handler
        @eval mod begin
            $name = RelationshipClass($value...)
            export $name
        end
    end
    for (name, value) in param_handler
        @eval mod begin
            $name = Parameter($value..., $mod)
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
    obj_cls_handler, rel_cls_handler, param_handler = spinedb_handle(db_map)
    for (name, value) in obj_cls_handler
        name in names(mod) || continue
        functor = getfield(mod, name)
        name, default_values, objects = value
        setdiff!(functor.objects, objects)
        empty!(functor.cache)
    end
    for (name, value) in rel_cls_handler
        name in names(mod) || continue
        functor = getfield(mod, name)
        name, default_values, obj_cls_name_tup, relationships = value
        obj_cls_name_tup == functor.object_class_names || continue
        setdiff!(functor.relationships, relationships)
        empty!(functor.cache)
    end
    for (name, value) in param_handler
        name in names(mod) || continue
        functor = getfield(mod, name)
        name, classes = value
        setdiff!(functor.classes, classes)
    end
end
