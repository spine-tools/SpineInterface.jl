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
    for (class_name, group_name, member_name) in groups
        push!(get!(d, (class_name, group_name), []), (class_name, member_name))
    end
    d
end

"""
A Dict mapping member ids to an Array of entity group ids.
"""
function _groups_per_member(groups)
    d = Dict()
    for (class_name, group_name, member_name) in groups
        push!(get!(d, (class_name, member_name), []), (class_name, group_name))
    end
    d
end

"""
A Dict mapping `Int64` ids to the corresponding `Object`.
"""
function _full_objects_per_id(objects, members_per_group, groups_per_member)
    objects_per_id = Dict(
        (class_name, name) => Object(name, class_name) for (id, (class_name, name, description)) in enumerate(objects)
    )
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
        class_name = ent[1]
        push!(get!(d, class_name, []), ent)
    end
    d
end

"""
A Dict mapping entity class ids to an Array of parameter definitions associated to that class.
"""
function _parameter_definitions_per_class(param_defs)
    d = Dict()
    for param_def in param_defs
        class_name = param_def[1]
        push!(get!(d, class_name, []), param_def)
    end
    d
end

"""
A Dict mapping tuples of parameter definition and entity ids, to an Array of corresponding parameter values.
"""
function _parameter_values_per_entity(param_values)
    Dict(
        (class_name, entity_name, param_name) => value
        for (class_name, entity_name, param_name, value, alt) in param_values
    )
end

function _try_parameter_value_from_db(db_value, err_msg)
    try
        if !(parse_db_value(db_value) isa TimeSeries)
            @show db_value
            @show parse_db_value(db_value)
        end
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
        Symbol(param_name) => _try_parameter_value_from_db(
            default_val, "unable to parse default value of `$(param_name)`"
        )
        for (class_name, param_name, default_val, vln, desc) in param_defs
    )
end

"""
A Dict mapping parameter names to their values for a given entity.
"""
function _parameter_values(entity_name, param_defs, param_vals_per_ent)
    Dict(
        Symbol(param_name) => _try_parameter_value_from_db(
            value, "unable to parse value of `$param_name` for `$entity_name`"
        )
        for (param_name, value) in (
            (param_name, get(param_vals_per_ent, (class_name, entity_name, param_name), nothing))
            for (class_name, param_name, default_val, val_lst_name, description) in param_defs
        )
        if value !== nothing
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

function _obj_class_args(class, objs_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    class_name = class[1]
    objects = get(objs_per_cls, class_name, ())
    param_defs = get(param_defs_per_cls, class_name, ())
    (
        _obj_and_vals(objects, full_objs_per_id, param_defs, param_vals_per_ent)...,
        _default_parameter_values(param_defs),
    )
end

function _obj_and_vals(objects, full_objs_per_id, param_defs, param_vals_per_ent)
    objects = [full_objs_per_id[class_name, obj_name] for (class_name, obj_name, description) in objects]
    param_vals = Dict(obj => _parameter_values(string(obj.name), param_defs, param_vals_per_ent) for obj in objects)
    objects, param_vals
end

function _rel_class_args(class, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    class_name = class[1]
    object_class_name_list = class[2]
    relationships = get(rels_per_cls, class_name, ())
    param_defs = get(param_defs_per_cls, class_name, ())
    (
        Symbol.(object_class_name_list),
        _rels_and_vals(object_class_name_list, relationships, full_objs_per_id, param_defs, param_vals_per_ent)...,
        _default_parameter_values(param_defs),
    )
end

function _rels_and_vals(object_class_name_list, relationships, full_objs_per_id, param_defs, param_vals_per_ent)
    object_tuples = [
        Tuple(
            full_objs_per_id[cls_name, obj_name]
            for (cls_name, obj_name) in zip(object_class_name_list, object_name_list)
        )
        for (rel_cls_name, object_name_list) in relationships
    ]
    param_vals = Dict(
        object_tuple => _parameter_values(string.(obj.name for obj in object_tuple), param_defs, param_vals_per_ent)
        for object_tuple in object_tuples
    )
    object_tuples, param_vals
end

"""
A Dict mapping class names to arguments.
"""
function _obj_args_per_class(classes, ents_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    Dict(
        Symbol(class[1]) => _obj_class_args(
            class, ents_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
        )
        for class in classes
    )
end

"""
A Dict mapping class names to arguments.
"""
function _rel_args_per_class(classes, ents_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    Dict(
        Symbol(class[1]) => _rel_class_args(
            class, ents_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
        )
        for class in classes
    )
end

"""
A Dict mapping parameter names to an Array of class names where the parameter is defined.
The Array of class names is sorted by decreasing number of dimensions in the class.
Note that for object classes, the number of dimensions is one.
"""
function _class_names_per_parameter(object_classes, relationship_classes, param_defs)
    d = Dict()
    for class in object_classes
        class_name = class[1]
        class_param_defs = get(param_defs, class_name, ())
        dim_count = 1
        for param_def in class_param_defs
            parameter_name = param_def[2]
            push!(get!(d, Symbol(parameter_name), Tuple{Symbol,Int64}[]), (Symbol(class_name), dim_count))
        end
    end
    for class in relationship_classes
        class_name = class[1]
        object_class_name_list = class[2]
        class_param_defs = get(param_defs, class_name, ())
        dim_count = length(object_class_name_list)
        for param_def in class_param_defs
            parameter_name = param_def[2]
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
function using_spinedb(url::String, mod=@__MODULE__; upgrade=false, filters=Dict(), on_conflict=:replace)
    uri = URI(url)    
    db = (uri.scheme == "http") ? uri : url
    data = _export_data(db; upgrade=upgrade, filters=filters)
    _generate_convenience_functions(data, mod; upgrade=upgrade, filters=filters, on_conflict=on_conflict)
end
function using_spinedb(
    template::Dict{String,T}, mod=@__MODULE__; upgrade=nothing, filters=nothing, on_conflict=:replace
) where T
    _generate_convenience_functions(template, mod; on_conflict=on_conflict)
end
function using_spinedb(
    template::Dict{Symbol,T}, mod=@__MODULE__; upgrade=nothing, filters=nothing, on_conflict=:replace
) where T
    using_spinedb(
        Dict(string(key) => value for (key, value) in template),
        mod=mod;
        upgrade=upgrade,
        filters=filters,
        on_conflict=on_conflict
    )
end

function _generate_convenience_functions(data, mod; upgrade=false, filters=Dict(), on_conflict=:replace)
    object_classes = get(data, "object_classes", [])
    relationship_classes = get(data, "relationship_classes", [])
    objects = get(data, "objects", [])
    object_groups = get(data, "object_groups", [])
    relationships = get(data, "relationships", [])
    obj_param_defs = get(data, "object_parameters", [])
    rel_param_defs = get(data, "relationship_parameters", [])
    obj_param_vals = get(data, "object_parameter_values", [])
    rel_param_vals = get(data, "relationship_parameter_values", [])
    param_defs = [obj_param_defs; rel_param_defs]
    param_vals = [obj_param_vals; rel_param_vals]
    members_per_group = _members_per_group(object_groups)
    groups_per_member = _groups_per_member(object_groups)
    full_objs_per_id = _full_objects_per_id(objects, members_per_group, groups_per_member)
    objs_per_cls = _entities_per_class(objects)
    rels_per_cls = _entities_per_class(relationships)
    param_defs_per_cls = _parameter_definitions_per_class(param_defs)
    param_vals_per_ent = _parameter_values_per_entity(param_vals)
    args_per_obj_cls = _obj_args_per_class(
        object_classes, objs_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
    )
    args_per_rel_cls = _rel_args_per_class(
        relationship_classes, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
    )
    class_names_per_param = _class_names_per_parameter(object_classes, relationship_classes, param_defs_per_cls)
    # Get or create containers
    _spine_object_classes = _getproperty!(mod, :_spine_object_classes, Dict())
    _spine_relationship_classes = _getproperty!(mod, :_spine_relationship_classes, Dict())
    _spine_parameters = _getproperty!(mod, :_spine_parameters, Dict())
    # Remove existing classes and parameters that are not in the new dataset
    for key in setdiff(keys(_spine_object_classes), keys(args_per_obj_cls))
        empty!(pop!(_spine_object_classes, key))
    end
    for key in setdiff(keys(_spine_relationship_classes), keys(args_per_rel_cls))
        empty!(pop!(_spine_relationship_classes, key))
    end
    for key in setdiff(keys(_spine_parameters), keys(class_names_per_param))
        empty!(pop!(_spine_parameters, key))
    end
    # Create new
    _fix_conflict! = get(Dict(:replace => _replace!, :merge => _merge!), on_conflict, _replace!)
    for (name, args) in args_per_obj_cls
        new = ObjectClass(name, args...)
        existing = get(_spine_object_classes, name, nothing)
        if existing != nothing
            _fix_conflict!(existing, new)
            continue
        end
        _spine_object_classes[name] = new
        @eval mod begin
            $name = $new
            export $name
        end
    end
    for (name, args) in args_per_rel_cls
        new = RelationshipClass(name, args...)
        existing = get(_spine_relationship_classes, name, nothing)
        if existing != nothing && existing.intact_object_class_names == new.intact_object_class_names
            _fix_conflict!(existing, new)
            continue
        end
        _spine_relationship_classes[name] = new
        @eval mod begin
            $name = $new
            export $name
        end
    end
    for (name, class_names) in class_names_per_param
        classes = [getfield(mod, x) for x in class_names]
        new = Parameter(name, classes)
        existing = get(_spine_parameters, name, nothing)
        if existing != nothing && getproperty.(existing.classes, :name) == getproperty.(new.classes, :name)
            _fix_conflict!(existing, new)
            continue
        end
        _spine_parameters[name] = new
        @eval mod begin
            $name = $new
            export $name
        end
    end
end

function _replace!(existing::T, new::T) where T <: Union{ObjectClass,RelationshipClass,Parameter}
    for x in propertynames(existing)
        _replace!(getproperty(existing, x), getproperty(new, x))
    end
end
function _replace!(x::Array, y::Array)
    empty!(x)
    _merge!(x, y)
end
function _replace!(x::Dict, y::Dict)
    empty!(x)
    _merge!(x, y)
end
_replace!(x, y) = nothing

function _merge!(existing::T, new::T) where T <: Union{ObjectClass,RelationshipClass,Parameter}
    for x in propertynames(existing)
        _merge!(getproperty(existing, x), getproperty(new, x))
    end
end
_merge!(x::Array, y::Array) = append!(x, setdiff(y, x))
_merge!(x::Dict, y::Dict) = merge!(_merge!, x, y)
function _merge!(x::T, y::T) where T <: AbstractParameterValue
    _merge!(x.value, y.value)
    x
end
_merge!(::NothingParameterValue, ::NothingParameterValue) = NothingParameterValue()
function _merge!(x::TimeSeries, y::TimeSeries)
    append!(x.indexes, y.indexes)
    append!(x.values, y.values)
    _sort_unique!(x.indexes, x.values)
    x
end
_merge!(x::RepeatingTimeSeriesParameterValue, y::RepeatingTimeSeriesParameterValue) = y  # TODO
_merge!(x::TimePatternParameterValue, y::TimePatternParameterValue) = y  # TODO
_merge!(x::MapParameterValue, y::MapParameterValue) = y  # TODO
_merge!(x, y) = y