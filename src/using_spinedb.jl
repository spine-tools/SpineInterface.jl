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
to a list of corresponding parameter parameter_values.
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
A dictionary mapping parameter names to their default parameter_values.
"""
function default_parameter_values(param_defs)
    d = Dict()
    for param_def in param_defs
        parameter_name = param_def["name"]
        default_value = param_def["default_value"]
        d[parameter_name] = try
            parameter_value(db_api.from_database(default_value))
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
A Dict mapping parameter names to their parameter_values for a given entity.
"""
function parameter_values(entity, param_defs, param_vals, default_vals)
    d = Dict{Symbol,AbstractParameterValue}()
    entity_id = entity["id"]
    entity_name = entity["name"]
    for param_def in param_defs
        parameter_id = param_def["id"]
        parameter_name = param_def["name"]
        value = get(param_vals, (parameter_id, entity_id), nothing)
        d[Symbol(parameter_name)] = if value === nothing
            copy(default_vals[parameter_name])
        else
            try
                parameter_value(db_api.from_database(value))
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
    end
    d
end


function fix_name_ambiguity(object_class_name_list::Array{T,1}) where T
    fixed = Array{T,1}()
    object_class_name_ocurrences = Dict{T,Int64}()
    for (i, object_class_name) in enumerate(object_class_name_list)
        n_ocurrences = count(x -> x == object_class_name, object_class_name_list)
        if n_ocurrences == 1
            push!(fixed, object_class_name)
        else
            ocurrence = get(object_class_name_ocurrences, object_class_name, 1)
            push!(fixed, string(object_class_name, ocurrence))
            object_class_name_ocurrences[object_class_name] = ocurrence + 1
        end
    end
    fixed
end


function class_handle(classes, entities, param_defs, param_vals)
    d = Dict()
    for class in classes
        class_id = class["id"]
        class_name = class["name"]
        class_param_defs = get(param_defs, class_id, ())
        default_vals = default_parameter_values(class_param_defs)
        class_entities = get(entities, class_id, [])
        vals = Dict(
            ent["id"] => parameter_values(ent, class_param_defs, param_vals, default_vals) for ent in class_entities
        )
        copyable_defaults = Dict(
            Symbol(p_name) => default
            for (p_name, default) in default_vals
        )
        d[Symbol(class_name)] = class_handle_entry(class, class_entities, vals, copyable_defaults)
    end
    d
end


function class_handle_entry(class, class_entities, vals, default_vals)
    object_class_names = get(class, "object_class_name_list", nothing)
    class_handle_entry(class, object_class_names, class_entities, vals, default_vals)
end

function class_handle_entry(class, ::Nothing, class_entities, vals, default_vals)
    class_objects = [Object(ent["name"], ent["id"]) for ent in class_entities]
    vals_ = Dict{Object,Dict{Symbol,AbstractParameterValue}}(obj => vals[obj.id] for obj in class_objects)
    Symbol(class["name"]), class_objects, vals_, default_vals
end

function class_handle_entry(class, object_class_names, class_entities, vals, default_vals)
    obj_cls_names = Symbol.(fix_name_ambiguity(split(object_class_names, ",")))
    class_relationships = []
    vals_ = Dict{Tuple{Vararg{Object}},Dict{Symbol,AbstractParameterValue}}()
    for ent in class_entities
        object_name_list = split(ent["object_name_list"], ",")
        object_id_list = parse.(Int, split(ent["object_id_list"], ","))
        objects = Object.(object_name_list, object_id_list)
        push!(class_relationships, NamedTuple{Tuple(obj_cls_names)}(objects))
        vals_[tuple(objects...)] = vals[ent["id"]]
    end
    Symbol(class["name"]), obj_cls_names, class_relationships, vals_, default_vals
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
    objs_per_cls = entities_per_class(objects)
    rels_per_cls = entities_per_class(relationships)
    param_defs_per_cls = parameter_definitions_per_class(param_defs)
    param_vals_per_cls = parameter_values_per_entity(param_vals)
    obj_class_handle = class_handle(object_classes, objs_per_cls, param_defs_per_cls, param_vals_per_cls)
    rel_class_handle = class_handle(relationship_classes, rels_per_cls, param_defs_per_cls, param_vals_per_cls)
    param_handle = parameter_handle([object_classes; relationship_classes], param_defs_per_cls)
    max_obj_id = reduce(max, (obj["id"] for obj in objects); init=0)
    obj_class_handle, rel_class_handle, param_handle, max_obj_id
end


"""
    using_spinedb(db_url::String, mod=@__MODULE__; upgrade=false)

Extend module `mod` with convenience functions to access the contents of the Spine db at the given RFC-1738 `url`.
If `upgrade` is `true`, then the database is upgraded to the latest revision.

See [`ObjectClass()`](@ref), [`RelationshipClass()`](@ref), and [`Parameter()`](@ref) for details on
how to call the convenience functors.
"""
function using_spinedb(db_url::String, mod=@__MODULE__; upgrade=false)
    db_map = DiffDatabaseMapping(db_url; upgrade=upgrade)
    using_spinedb(db_map, mod)
end

function using_spinedb(db_map::PyObject, mod=@__MODULE__)
    obj_class_handle, rel_class_handle, param_handle, max_obj_id = spinedb_handle(db_map)
    id_factory = ObjectIdFactory(UInt64(max_obj_id))
    @eval mod begin
        function SpineInterface.Object(name::Symbol; id_factory=$id_factory)
            Object(name, SpineInterface._next_id(id_factory))
        end
    end
    @eval mod begin
        _spine_object_class = Vector{ObjectClass}()
        _spine_relationship_class = Vector{RelationshipClass}()
        _spine_parameter = Vector{Parameter}()
        sizehint!(_spine_object_class, $(length(obj_class_handle)))
        sizehint!(_spine_relationship_class, $(length(rel_class_handle)))
        sizehint!(_spine_parameter, $(length(param_handle)))
    end
    for (name, handle) in obj_class_handle
        object_class = ObjectClass(handle...)
        @eval mod begin
            $name = $object_class
            push!(_spine_object_class, $name)
            export $name
        end
    end
    for (name, handle) in rel_class_handle
        relationship_class = RelationshipClass(handle...)
        @eval mod begin
            $name = $relationship_class
            push!(_spine_relationship_class, $name)
            export $name
        end
    end
    for (name, handle) in param_handle
        name_, class_names = handle
        classes = [getfield(mod, x) for x in class_names]
        parameter = Parameter(name_, classes)
        @eval mod begin
            $name = $parameter
            push!(_spine_parameter, $name)
            export $name
        end
    end
end

function notusing_spinedb(db_url::String, mod=@__MODULE__; upgrade=false)
    db_map = db_api.DiffDatabaseMapping(db_url, upgrade=upgrade)
    notusing_spinedb(db_map, mod)
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
