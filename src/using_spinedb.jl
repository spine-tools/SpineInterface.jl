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

"""
A Dict mapping entity group ids to an Array of member ids.
"""
function _members_per_group(groups)
    d = Dict()
    for grp in groups
        push!(get!(d, grp["entity_id"], []), grp["member_id"])
    end
    d
end

"""
A Dict mapping member ids to an Array of entity group ids.
"""
function _groups_per_member(groups)
    d = Dict()
    for grp in groups
        push!(get!(d, grp["member_id"], []), grp["entity_id"])
    end
    d
end

"""
A Dict mapping `Int64` ids to the corresponding `Object`.
"""
function _full_objects_per_id(objects, members_per_group, groups_per_member)
    objects_per_id = Dict{Int64,Object}(obj["id"] => Object(obj["name"], obj["id"]) for obj in objects)
    # Specify `members` for each group
    for (id, object) in objects_per_id
        member_ids = get(members_per_group, id, ())
        members = isempty(member_ids) ? [object] : [objects_per_id[member_id] for member_id in member_ids]
        append!(object.members, members)
    end
    # Specify `groups` for each member
    for (id, object) in objects_per_id
        group_ids = get(groups_per_member, id, ())
        groups = [objects_per_id[group_id] for group_id in group_ids]
        append!(object.groups, groups)
    end
    objects_per_id
end

"""
A Dict mapping class ids to an Array of entities in that class.
"""
function _entities_per_class(entities)
    d = Dict()
    for ent in entities
        push!(get!(d, ent["class_id"], Dict[]), ent)
    end
    d
end

"""
A Dict mapping entity class ids to an Array of parameter definitions associated to that class.
"""
function _parameter_definitions_per_class(param_defs)
    d = Dict()
    for param_def in param_defs
        class_id = param_def["entity_class_id"]
        push!(get!(d, class_id, Dict[]), param_def)
    end
    d
end

"""
A Dict mapping tuples of parameter definition and entity ids, to an Array of corresponding parameter values.
"""
function _parameter_values_per_entity(param_values)
    Dict(
        (val["parameter_definition_id"], val["entity_id"]) => val["value"] for val in param_values
    )
end

function _try_parameter_value_from_db(db_value, err_msg)
    try
        parameter_value(parse_db_value(db_value))
    catch e
        rethrow(ErrorException("$err_msg: $(sprint(showerror, e))"))
    end
end

"""
A Dict mapping parameter names to their default values.
"""
function _default_parameter_values(param_defs)
    Dict(
        Symbol(def["name"]) =>
            _try_parameter_value_from_db(def["default_value"], "unable to parse default value of `$(def["name"])`") for
        def in param_defs
    )
end

"""
A Dict mapping parameter names to their values for a given entity.
"""
function _parameter_values(entity, param_defs, param_vals_per_ent)
    Dict(
        Symbol(parameter_name) =>
            _try_parameter_value_from_db(value, "unable to parse value of `$parameter_name` for `$(entity["name"])`")
        for (parameter_name, value) in
        ((def["name"], get(param_vals_per_ent, (def["id"], entity["id"]), nothing)) for def in param_defs) if
        value !== nothing
    )
end

"""
Append an increasing integer to each repeated element in `name_list`, and return the modified `name_list`.
"""
function _fix_name_ambiguity(intact_name_list::Array{Symbol,1})
    name_list = copy(intact_name_list)
    for ambiguous in Iterators.filter(name -> count(name_list .== name) > 1, unique(name_list))
        for (k, index) in enumerate(findall(name_list .== ambiguous))
            name_list[index] = Symbol(name_list[index], k)
        end
    end
    name_list
end

function _object_tuple_from_relationship(rel::Dict, full_objs_per_id)
    object_ids = parse.(Int, split(rel["object_id_list"], ","))
    Tuple(full_objs_per_id[id] for id in object_ids)
end

function _class_args(class, ents_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    entities = get(ents_per_cls, class["id"], ())
    param_defs = get(param_defs_per_cls, class["id"], ())
    object_class_name_list = get(class, "object_class_name_list", nothing)
    (
        _ents_and_vals(object_class_name_list, entities, full_objs_per_id, param_defs, param_vals_per_ent)...,
        _default_parameter_values(param_defs),
    )
end

function _ents_and_vals(::Nothing, entities, full_objs_per_id, param_defs, param_vals_per_ent)
    objects = [full_objs_per_id[ent["id"]] for ent in entities]
    param_vals =
        Dict(obj => _parameter_values(ent, param_defs, param_vals_per_ent) for (obj, ent) in zip(objects, entities))
    objects, param_vals
end
function _ents_and_vals(object_class_name_list, entities, full_objs_per_id, param_defs, param_vals_per_ent)
    intact_object_class_names = Symbol.(split(object_class_name_list, ","))
    object_class_names = _fix_name_ambiguity(intact_object_class_names)
    object_tuples = (_object_tuple_from_relationship(ent, full_objs_per_id) for ent in entities)
    relationships = [(; zip(object_class_names, objects)...) for objects in object_tuples]
    param_vals = Dict(
        objects => _parameter_values(ent, param_defs, param_vals_per_ent) for
        (objects, ent) in zip(object_tuples, entities)
    )
    object_class_names, relationships, param_vals, intact_object_class_names
end

"""
A Dict mapping class names to arguments.
"""
function _args_per_class(classes, ents_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    Dict(
        Symbol(class["name"]) =>
            _class_args(class, ents_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent) for
        class in classes
    )
end

"""
A Dict mapping parameter names to an Array of class names where the parameter is defined.
The Array of class names is sorted by decreasing number of dimensions in the class.
Note that for object classes, the number of dimensions is one.
"""
function _class_names_per_parameter(classes, param_defs)
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
    Dict(name => first.(sort(tups; by=last, rev=true)) for (name, tups) in d)
end

"""
    using_spinedb(url::String, mod=@__MODULE__; upgrade=false)

Extend module `mod` with convenience functions to access the contents of a Spine DB.
The argument `url` is either the url of the DB, or of an HTTP Spine DB server associated with it.
If `upgrade` is `true`, then the database is upgraded to the latest revision.

See [`ObjectClass()`](@ref), [`RelationshipClass()`](@ref), and [`Parameter()`](@ref) for details on
how to call the convenience functors.
"""
function using_spinedb(url::String, mod=@__MODULE__; upgrade=false)
    uri = URI(url)    
    db = (uri.scheme == "http") ? uri : url
    data = _get_data(db; upgrade=upgrade)
    object_classes = data["object_class_sq"]
    relationship_classes = data["wide_relationship_class_sq"]
    objects = data["object_sq"]
    groups = data["entity_group_sq"]
    relationships = data["wide_relationship_sq"]
    param_defs = data["parameter_definition_sq"]
    param_vals = data["parameter_value_sq"]
    members_per_group = _members_per_group(groups)
    groups_per_member = _groups_per_member(groups)
    full_objs_per_id = _full_objects_per_id(objects, members_per_group, groups_per_member)
    objs_per_cls = _entities_per_class(objects)
    rels_per_cls = _entities_per_class(relationships)
    param_defs_per_cls = _parameter_definitions_per_class(param_defs)
    param_vals_per_ent = _parameter_values_per_entity(param_vals)
    args_per_obj_cls =
        _args_per_class(object_classes, objs_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    args_per_rel_cls =
        _args_per_class(relationship_classes, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    class_names_per_param = _class_names_per_parameter([object_classes; relationship_classes], param_defs_per_cls)
    max_obj_id = reduce(max, (obj["id"] for obj in objects); init=0)
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
        sizehint!(_spine_object_class, $(length(args_per_obj_cls)))
        sizehint!(_spine_relationship_class, $(length(args_per_rel_cls)))
        sizehint!(_spine_parameter, $(length(class_names_per_param)))
    end
    for (name, args) in args_per_obj_cls
        object_class = ObjectClass(name, args...)
        @eval mod begin
            $name = $object_class
            push!(_spine_object_class, $name)
            export $name
        end
    end
    for (name, args) in args_per_rel_cls
        relationship_class = RelationshipClass(name, args...)
        @eval mod begin
            $name = $relationship_class
            push!(_spine_relationship_class, $name)
            export $name
        end
    end
    for (name, class_names) in class_names_per_param
        classes = [getfield(mod, x) for x in class_names]
        parameter = Parameter(name, classes)
        @eval mod begin
            $name = $parameter
            push!(_spine_parameter, $name)
            export $name
        end
    end
end
