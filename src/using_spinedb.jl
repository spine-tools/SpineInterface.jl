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
A dictionary mapping class ids to a list of entities in that class.
"""
function entities_per_class(entities)
    d = Dict()
    for ent in entities
        push!(get!(d, ent["class_id"], Dict[]), ent)
    end
    d
end

not_nothing(x, ::Nothing) = x
not_nothing(::Nothing, x) = x

"""
A dictionary mapping entity class ids to a list of parameter definitions associated to that class.
"""
function parameter_definitions_per_class(param_defs)
    d = Dict()
    for param_def in param_defs
        class_id = not_nothing(param_def["object_class_id"], param_def["relationship_class_id"])
        push!(get!(d, class_id, Dict[]), param_def)
    end
    d
end

"""
A dictionary mapping tuples of parameter definition and entity ids,
to a list of corresponding parameter values.
"""
function parameter_values_per_entity(param_values)
    d = Dict()
    for param_val in param_values
        parameter_id = param_val["parameter_definition_id"]
        entity_id = not_nothing(param_val["object_id"], param_val["relationship_id"])
        d[parameter_id, entity_id] = param_val["value"]
    end
    d
end


"""
A dictionary mapping parameter names to their default values.
"""
function default_values(param_defs)
    d = Dict()
    for param_def in param_defs
        parameter_name = param_def["name"]
        default_value = param_def["default_value"]
        d[parameter_name] = try
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
    d
end


"""
A named tuple mapping parameter names to their values for a given entity.
"""
function given_values(entity, param_defs, param_vals, default_vals)
    d = Dict()
    entity_id = entity["id"]
    entity_name = entity["name"]
    for param_def in param_defs
        parameter_id = param_def["id"]
        parameter_name = param_def["name"]
        value = get(param_vals, (parameter_id, entity_id), nothing)
        if value === nothing
            d[Symbol(parameter_name)] = copy(default_vals[parameter_name])
            continue
        end
        d[Symbol(parameter_name)] = try
            callable(db_api.from_database(value))
        catch e
            if e isa PyCall.PyError && e.T == db_api.ParameterValueFormatError
                rethrow(
                    ErrorException(
                        """
                        unable to parse value of '$parameter_name' for '$entity_name':
                        $(sprint(showerror, e))
                        """
                    )
                )
            else
                rethrow()
            end
        end
    end
    (;d...)
end


function class_handle(classes, entities, param_defs, param_vals)
    d = Dict()
    for class in classes
        class_id = class["id"]
        class_name = class["name"]
        class_param_defs = get(param_defs, class_id, ())
        default_vals = default_values(class_param_defs)
        class_entities = get(entities, class_id, [])
        vals = Dict(
            ent["id"] => given_values(ent, class_param_defs, param_vals, default_vals) for ent in class_entities
        )
        d[Symbol(class_name)] = class_handle_entry(class, class_entities, vals)
    end
    d
end


function class_handle_entry(class, class_entities, vals)
    object_class_names = get(class, "object_class_name_list", nothing)
    class_handle_entry(class, object_class_names, class_entities, vals)
end

function class_handle_entry(class, ::Nothing, class_entities, vals)
    class_objects = [Object(ent["name"], ent["id"]) for ent in class_entities]
    vals_ = Dict{Object,NamedTuple}(obj => vals[obj.id] for obj in class_objects)
    Symbol(class["name"]), class_objects, vals_
end

function class_handle_entry(class, object_class_names, class_entities, vals)
    obj_cls_name_tup = Tuple(Symbol.(fix_name_ambiguity(split(object_class_names, ","))))
    class_relationships = []
    vals_ = Dict{Tuple{Vararg{Object}},NamedTuple}()
    for ent in class_entities
        object_name_list = split(ent["object_name_list"], ",")
        object_id_list = parse.(Int, split(ent["object_id_list"], ","))
        objects = Object.(object_name_list, object_id_list)
        push!(class_relationships, NamedTuple{obj_cls_name_tup}(objects))
        vals_[tuple(objects...)] = vals[ent["id"]]
    end
    Symbol(class["name"]), obj_cls_name_tup, class_relationships, vals_
end


"""
A dictionary mapping parameter names to a collection of class names where the parameter is defined.
The collection of class names is sorted by decreasing number of dimensions in the class.
Note that for object classes, the number of dimensions is one.
"""
function parameter_handle(classes, param_defs)
    d = Dict()
    for class in classes
        class_id = class["id"]
        class_name = class["name"]
        class_param_defs = get(param_defs, class_id, ())
        dim_count = length(split(get(class, "object_class_id_list", ""), ","))
        for param_def in class_param_defs
            parameter_name = param_def["name"]
            push!(get!(d, Symbol(parameter_name), Tuple{Symbol,Int64}[]), (Symbol(class_name), dim_count))
        end
    end
    Dict(name => (name, first.(sort(tups; by=last, rev=true))) for (name, tups) in d)
end


function spinedb_handle(db_map::PyObject)
    object_classes = py"[x._asdict() for x in $db_map.query($db_map.object_class_sq)]"
    relationship_classes = py"[x._asdict() for x in $db_map.query($db_map.wide_relationship_class_sq)]"
    objects = py"[x._asdict() for x in $db_map.query($db_map.object_sq)]"
    relationships = py"[x._asdict() for x in $db_map.query($db_map.wide_relationship_sq)]"
    param_defs = py"[x._asdict() for x in $db_map.query($db_map.parameter_definition_sq)]"
    param_vals = py"[x._asdict() for x in $db_map.query($db_map.parameter_value_sq)]"
    objects = entities_per_class(objects)
    relationships = entities_per_class(relationships)
    param_defs = parameter_definitions_per_class(param_defs)
    param_vals = parameter_values_per_entity(param_vals)  
    obj_class_handle = class_handle(object_classes, objects, param_defs, param_vals)
    rel_class_handle = class_handle(relationship_classes, relationships, param_defs, param_vals)
    param_handle = parameter_handle([object_classes; relationship_classes], param_defs)
    obj_class_handle, rel_class_handle, param_handle
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

                You can upgrade it by running `using_spinedb(db_url; upgrade=true)`.

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
    obj_class_handle, rel_class_handle, param_handle = spinedb_handle(db_map)
    for (name, value) in obj_class_handle
        @eval mod begin
            $name = ObjectClass($value...)
            export $name
        end
    end
    for (name, value) in rel_class_handle
        @eval mod begin
            $name = RelationshipClass($value...)
            export $name
        end
    end
    for (name, value) in param_handle
        name_, classes = value
        classes_ = [getfield(mod, x) for x in classes]
        @eval mod begin
            $name = Parameter($(Expr(:quote, name_)), $classes_)
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

                You can upgrade it by running `notusing_spinedb(db_url; upgrade=true)`.

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
    obj_class_handle, rel_class_handle, param_handle = spinedb_handle(db_map)
    for (name, value) in obj_class_handle
        name in names(mod) || continue
        functor = getfield(mod, name)
        name, objects = value
        setdiff!(functor.objects, objects)
        empty!(functor.cache)
    end
    for (name, value) in rel_class_handle
        name in names(mod) || continue
        functor = getfield(mod, name)
        name, obj_cls_name_tup, relationships = value
        obj_cls_name_tup == functor.object_class_names || continue
        setdiff!(functor.relationships, relationships)
        empty!(functor.cache)
    end
    for (name, value) in param_handle
        name in names(mod) || continue
        functor = getfield(mod, name)
        name, classes = value
        setdiff!(functor.classes, [getfield(mod, x) for x in classes])
    end
end
