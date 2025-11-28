#############################################################################
# Copyright (C) 2017 - 2021 Spine project consortium
# Copyright SpineInterface contributors
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
    using_spinedb(url::String, mod=@__MODULE__; upgrade=false, filters=Dict(), extend=false)

Extend module `mod` with convenience functions to access the contents of a Spine DB.
The argument `url` is either the url of the DB, or of an HTTP Spine DB server associated with it.

# Keyword arguments
  - `upgrade`: if `true`, then the database is upgraded to the latest revision.
  - `filters`: a `Dict` specifying filters.
  - `extend`: if `false`, then any convenience functions already created in the given module are
    overwritten. Otherwise they are extended.

See [`ObjectClass()`](@ref), [`RelationshipClass()`](@ref), and [`Parameter()`](@ref) for details on
how to call the convenience functors.
"""
function using_spinedb(url::String, mod=@__MODULE__; upgrade=false, filters=Dict(), extend=false)
    data = export_data(url; upgrade=upgrade, filters=filters)
    _generate_convenience_functions(data, mod; filters=filters, extend=extend)
end
function using_spinedb(template::Dict{Symbol,T}, mod=@__MODULE__; filters=nothing, extend=false) where T
    using_spinedb(Dict(string(key) => value for (key, value) in template), mod; filters=filters, extend=extend)
end
function using_spinedb(template::Dict{String,T}, mod=@__MODULE__; filters=nothing, extend=false) where T
    _generate_convenience_functions(template, mod; filters=filters, extend=extend)
end

"""
A Dict mapping entity group names to an Array of member names.
"""
function _members_per_group(groups)
    d = Dict()
    for (class_name, group_name, member_name) in groups
        push!(get!(d, group_name, []), member_name)
    end
    d
end

"""
A Dict mapping member names to an Array of entity group names.
"""
function _groups_per_member(groups)
    d = Dict()
    for (class_name, group_name, member_name) in groups
        push!(get!(d, member_name, []), group_name)
    end
    d
end

"""
A Dict mapping superclass names to their subclass names.
"""
function _subclasses_per_superclass(superclass_subclass)
    d = Dict()
    for (superclass_name, subclass_name) in superclass_subclass
        push!(get!(d, superclass_name, []), subclass_name)
    end 
    return d
end

"""
A `Vector` of byobject class names.
"""
function _byobject_classes(object_classes, subclasses_per_superclass)
    return Symbol.(setdiff(
        getindex.(object_classes, 1), keys(subclasses_per_superclass)
    ))
end

"""
A Dict mapping `Object` names to the corresponding `Object`.
"""
function _full_objects_per_id(objects, members_per_group, groups_per_member)
    objects_per_id = Dict(
        name => Object(name, class_name) for (class_name, name) in objects
    )
    # Specify `members` for each group
    for (name, object) in objects_per_id
        member_names = get(members_per_group, name, ())
        members = isempty(member_names) ? [object] : [objects_per_id[member_name] for member_name in member_names]
        append!(object.members, members)
    end
    # Specify `groups` for each member
    for (name, object) in objects_per_id
        group_names = get(groups_per_member, name, ())
        groups = [objects_per_id[group_name] for group_name in group_names]
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
        push!(get!(d, ent[1], []), ent)
    end
    d
end

"""
A Dict mapping entity class ids to an Array of parameter definitions associated to that class.
"""
function _parameter_definitions_per_class(param_defs)
    d = Dict()
    for param_def in param_defs
        push!(get!(d, param_def[1], []), param_def)
    end
    d
end

"""
A Dict mapping tuples of parameter definition and entity ids, to an Array of corresponding parameter values.
"""
function _parameter_values_per_entity(param_values)
    Dict(
        (class_name, entity_name, param_name) => value
        for (class_name, entity_name, param_name, value) in param_values
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
        Symbol(param_name) => _try_parameter_value_from_db(
            default_val, "unable to parse default value of `$(param_name)`"
        )
        for (class_name, param_name, default_val) in param_defs
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
            for (class_name, param_name) in param_defs
        )
        if value !== nothing
    )
end

function _obj_class_args(
    class,
    objs_per_cls,
    full_objs_per_id,
    param_defs_per_cls,
    param_vals_per_ent,
    subclasses_per_superclass
)
    class_name, = class
    objects = get(objs_per_cls, class_name, ())
    param_defs = get(param_defs_per_cls, class_name, ())
    (
        _obj_and_vals(objects, full_objs_per_id, param_defs, param_vals_per_ent)...,
        _default_parameter_values(param_defs),
        Symbol.(get(subclasses_per_superclass, class_name, []))
    )
end

function _obj_and_vals(objects, full_objs_per_id, param_defs, param_vals_per_ent)
    objects = [full_objs_per_id[obj_name] for (class_name, obj_name) in objects]
    param_vals = Dict(obj => _parameter_values(string(obj.name), param_defs, param_vals_per_ent) for obj in objects)
    objects, param_vals
end

function _rel_class_args(class, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    class_name, object_class_name_list = class
    relationships = get(rels_per_cls, class_name, ())
    param_defs = get(param_defs_per_cls, class_name, ())
    (
        Symbol.(object_class_name_list),
        _rels_and_vals(relationships, full_objs_per_id, param_defs, param_vals_per_ent)...,
        _default_parameter_values(param_defs),
    )
end

function _rels_and_vals(relationships, full_objs_per_id, param_defs, param_vals_per_ent)
    object_tuples = [
        Tuple(
            full_objs_per_id[obj_name]
            for obj_name in object_name_list
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
A Dict mapping object class names to arguments.
"""
function _obj_args_per_class(
    classes,
    ents_per_cls,
    full_objs_per_id,
    param_defs_per_cls,
    param_vals_per_ent,
    subclasses_per_superclass,
)
    Dict(
        Symbol(class[1]) => _obj_class_args(
            class,
            ents_per_cls,
            full_objs_per_id,
            param_defs_per_cls,
            param_vals_per_ent,
            subclasses_per_superclass
        )
        for class in classes
    )
end

"""
A Dict mapping relationship class names to arguments.
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
    for (class_name,) in object_classes
        class_param_defs = get(param_defs, class_name, ())
        dim_count = 1
        for (class_name, parameter_name) in class_param_defs
            push!(get!(d, Symbol(parameter_name), Tuple{Symbol,Int64}[]), (Symbol(class_name), dim_count))
        end
    end
    for (class_name, object_class_name_list) in relationship_classes
        class_param_defs = get(param_defs, class_name, ())
        dim_count = length(object_class_name_list)
        for (class_name, parameter_name) in class_param_defs
            push!(get!(d, Symbol(parameter_name), Tuple{Symbol,Int64}[]), (Symbol(class_name), dim_count))
        end
    end
    Dict(name => first.(sort(tups; by=last, rev=true)) for (name, tups) in d)
end

"""
    _split_superrel_args!(
        args_per_rel_cls, byobject_classes, subclasses_per_superclass
    )

Updates `args_per_rel_cls` by splitting compound relationship classes into subclasses.

Returns the updated `args_per_rel_cls` as well as a `Dict` mapping the original
compound relationship classes to their newly generated subclasses.
"""
function _split_superrel_args!(
    args_per_rel_cls, byobject_classes, subclasses_per_superclass
)
    superrel_subrel_map_name = Dict()
    isempty(args_per_rel_cls) && return args_per_rel_cls, superrel_subrel_map_name
    # Separate compound relationships that need to be split.
    args_per_superrel = _pop_superrels!(args_per_rel_cls, byobject_classes)
    isempty(args_per_superrel) && return args_per_rel_cls, superrel_subrel_map_name
    # Figure out the necessary dimension permutations for the sub-relationships
    new_args_per_subrel = Dict()
    for (name, superrel) in args_per_superrel
        new_subrels, new_map = _subrel_args(
            name, superrel, byobject_classes, args_per_rel_cls, subclasses_per_superclass
        )
        merge!(new_args_per_subrel, new_subrels)
        push!(superrel_subrel_map_name, new_map)
    end
    # Merge newly splitted subrels back into 
    return merge!(args_per_rel_cls, new_args_per_subrel), superrel_subrel_map_name
end

"""
Pop a new relationship class argument Dict needing to be divided into subclasses.
"""
function _pop_superrels!(args_per_rel_cls, byobj_classes)
    d = Dict()
    for (rel_name, rel_class) in args_per_rel_cls
        if all(dim in byobj_classes for dim in rel_class[1])
            continue
        else
            d[rel_name] = pop!(args_per_rel_cls, rel_name)
        end
    end
    return d
end

"""
    _subrel_args(
        name, superrel, byobject_classes, args_per_rel_cls, subclasses_per_superclass
    )

Return a `Dict` with arguments for subrel creation splitting `superrel`.
Also returns a pair mapping `superrel` `name` to its subrels' names.
"""
function _subrel_args(
    name, superrel, byobject_classes, args_per_rel_cls, subclasses_per_superclass
)
    # Determine all possible permutations of byclasses for the subrels. 
    subrel_dimensions = _recursive_fetch_dimension_permutations(
        [superrel[1]],
        byobject_classes,
        args_per_rel_cls,
        subclasses_per_superclass
    )
    name_map = name => []
    subrel_args = Dict()
    # Loop over subrels-to-be and split superrel constructor arguments among them.
    for subrel in subrel_dimensions
        subrel_name = _generate_relationship_class_name(subrel; prefix=name)
        push!(name_map[2], subrel_name)
        push!(
            subrel_args,
            subrel_name => (
                subrel,
                filter(
                    objtup -> getfield.(objtup, :class_name) == (subrel...,),
                    superrel[2]
                ),
                filter(
                    key_val -> getfield.(key_val[1], :class_name) == (subrel...,),
                    superrel[3]
                ),
                superrel[4]
            )
        )
    end
    return subrel_args, name_map
end

"""
    _recursive_fetch_dimension_permutations(
        dim_perms::Vector{Vector{Symbol}},
        byobj_classes::Vector{Symbol},
        args_per_rel_cls,
        subclasses_per_superclass
    )

Return a `Vector{Vector{Symbol}}` of possible byclass dimension permutations of `dim_perms`.

Essentially recursively navigates `args_per_rel_cls` and `subclasses_per_superclass`
to find all potential permutations of the `byobj_classes`.
Used for splitting Spine-Database-API compound relationship classes into flat
subclasses for [`RelationshipClass`](@ref) constructors.
"""
function _recursive_fetch_dimension_permutations(
    dim_perms::Vector{Vector{Symbol}},
    byobj_classes::Vector{Symbol},
    args_per_rel_cls,
    subclasses_per_superclass
)
    # If all dimension permutations only contain byobject class names, return.
    if all(all(name in byobj_classes for name in dim_names) for dim_names in dim_perms)
        return dim_perms
    else
        new_dim_perms = Vector{Vector{Symbol}}()
        # Expand superclass permutations
        for perm in dim_perms
            new_perm = Vector{Vector{Symbol}}()
            for dim_name in perm
                push!(
                    new_perm,
                    Symbol.(get(subclasses_per_superclass, string(dim_name), [dim_name]))
                )
            end
            for dims in Iterators.product(new_perm...)
                push!(new_dim_perms, collect(dims))
            end
        end
        # Expand relationship classes to their elements
        new_dim_perms = [
            vcat(
                [get(args_per_rel_cls, name, [name])[1] for name in perm]...
            )
            for perm in new_dim_perms
        ]
        # Begin the process anew for the next iteration.
        return _recursive_fetch_dimension_permutations(
            new_dim_perms,
            byobj_classes,
            args_per_rel_cls,
            subclasses_per_superclass
        )
    end
end

"""
Return a single symbol joining the individual dimension names with `__`.
"""
function _generate_relationship_class_name(
    dimension_vector::Vector{Symbol}; prefix=nothing
)
    name_to_be = join(string.(dimension_vector), "__")
    if isnothing(prefix) || string(prefix) == name_to_be # Avoid name duplication!
        return Symbol(name_to_be)
    else
        return Symbol(join([string(prefix), name_to_be], "__"))
    end
end

"""
    _add_pseudo_superclasses!(args_per_obj_cls, superrel_to_subrels_name_map)

Add pseudo-superrel arguments to [`ObjectClass`](@ref) generation.
"""
function _add_pseudo_superclasses!(args_per_obj_cls, superrel_to_subrels_name_map)
    for (superrel, subrels) in superrel_to_subrels_name_map
        superrel == first(subrels) && continue # If superrel name matches its subrel, skip.
        push!(args_per_obj_cls, superrel => ([], Dict(), Dict(), subrels))
    end
    return args_per_obj_cls
end

"""
    _split_superrel_params!(class_names_per_param, superrel_to_subrels_name_map)

Split super-relationship classes to their subrelationship classes for [`Parameter`](@ref) constructors.
"""
function _split_superrel_params!(class_names_per_param, superrel_to_subrels_name_map)
    for (superrel, subrels) in superrel_to_subrels_name_map
        for (param_name, param_classes) in class_names_per_param
            ind = findfirst(superrel .== param_classes)
            isnothing(ind) && continue
            popat!(param_classes, ind)
            append!(param_classes, subrels)
        end
    end
    return class_names_per_param
end

function _generate_convenience_functions(data, mod; filters=Dict(), extend=false)
    object_classes = get(data, "object_classes") do
        [x for x in get(data, "entity_classes", []) if isempty(x[2])]
    end
    relationship_classes = get(data, "relationship_classes") do
        [x for x in get(data, "entity_classes", []) if !isempty(x[2])]
    end
    objects = get(data, "objects") do
        [x for x in get(data, "entities", []) if x[2] isa String]
    end
    relationships = get(data, "relationships") do
        [x for x in get(data, "entities", []) if !(x[2] isa String)]
    end
    object_groups = get(data, "object_groups") do
        get(data, "entity_groups", [])
    end
    param_defs = get(data, "parameter_definitions") do
        vcat(get(data, "object_parameters", []), get(data, "relationship_parameters", []))
    end
    param_vals = get(data, "parameter_values") do
        vcat(get(data, "object_parameter_values", []), get(data, "relationship_parameter_values", []))
    end
    superclass_subclass = get(data, "superclass_subclasses") do
        get(data, "superclass_subclasses", [])
    end
    members_per_group = _members_per_group(object_groups)
    groups_per_member = _groups_per_member(object_groups)
    subclasses_per_superclass = _subclasses_per_superclass(superclass_subclass)
    full_objs_per_id = _full_objects_per_id(objects, members_per_group, groups_per_member)
    objs_per_cls = _entities_per_class(objects)
    rels_per_cls = _entities_per_class(relationships)
    param_defs_per_cls = _parameter_definitions_per_class(param_defs)
    param_vals_per_ent = _parameter_values_per_entity(param_vals)
    args_per_obj_cls = _obj_args_per_class(
        object_classes,
        objs_per_cls,
        full_objs_per_id,
        param_defs_per_cls,
        param_vals_per_ent,
        subclasses_per_superclass
    )
    args_per_rel_cls = _rel_args_per_class(
        relationship_classes, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
    )
    class_names_per_param = _class_names_per_parameter(object_classes, relationship_classes, param_defs_per_cls)
    # Generate pseudo-compound-superclass structure on top of previous stuff.
    byobject_classes = _byobject_classes(object_classes, subclasses_per_superclass)
    args_per_rel_cls, superrel_to_subrels_name_map = _split_superrel_args!(
        args_per_rel_cls,
        byobject_classes,
        subclasses_per_superclass
    )
    _add_pseudo_superclasses!(args_per_obj_cls, superrel_to_subrels_name_map)
    _split_superrel_params!(class_names_per_param, superrel_to_subrels_name_map)
    # Get or create containers
    spine_object_classes = _getproperty!(mod, :_spine_object_classes, Dict())
    spine_relationship_classes = _getproperty!(mod, :_spine_relationship_classes, Dict())
    spine_parameters = _getproperty!(mod, :_spine_parameters, Dict())
    if !extend
        env = _active_env()
        for elements in (spine_object_classes, spine_relationship_classes, spine_parameters)
            for (name, x) in collect(elements)
                if isempty(delete!(x.env_dict, env))
                    pop!(elements, name)
                    @eval mod $name = nothing
                end
            end
        end
    end
    # Create new
    for (name, args) in args_per_obj_cls
        new = ObjectClass(name, args...; mod=mod, extend=extend)
        @eval mod begin
            $name = $new
            export $name
        end
    end
    for (name, args) in args_per_rel_cls
        new = RelationshipClass(name, args...; mod=mod, extend=extend)
        @eval mod begin
            $name = $new
            export $name
        end
    end
    for (name, class_names) in class_names_per_param
        classes = [getfield(mod, x) for x in class_names]
        new = Parameter(name, classes; mod=mod, extend=extend)
        @eval mod begin
            $name = $new
            export $name
        end
    end
    # Resolve superclass subclass names.
    # Tasku: A better way would be to actually type `_ObjectClass` `subclasses`
    # field to `Vector{EntityClass}`, but I couldn't get that to work
    # with the time I had available to me.
    for obj_cls in [object_class(name, mod) for name in keys(args_per_obj_cls)]
        for (i, subcls_name) in enumerate(obj_cls.subclasses)
            obj_cls.subclasses[i] = entity_class(subcls_name, mod)
        end
    end
end

"""
    write_parameters(parameters, url::String; <keyword arguments>)

Write `parameters` to the Spine database at the given RFC-1738 `url`.
`parameters` is a dictionary mapping parameter names to another dictionary
mapping object or relationship (`NamedTuple`) to values.

# Arguments

  - `parameters::Dict`: a dictionary mapping parameter names, to entities, to parameter values
  - `upgrade::Bool=true`: whether or not the database at `url` should be upgraded to the latest revision.
  - `for_object::Bool=true`: whether to write an object parameter or a 1D relationship parameter in case the number of
    dimensions is 1.
  - `report::String=""`: the name of a report object that will be added as an extra dimension to the written parameters.
  - `alternative::String`: an alternative where to write the parameter values.
  - `comment::String=""`: a comment explaining the nature of the writing operation.
"""
function write_parameters(
    parameters::Dict,
    url::String;
    upgrade=true,
    for_object=true,
    report="",
    alternative="",
    on_conflict="merge",
    comment=""
)
    data = Dict{Symbol,Any}(:on_conflict => on_conflict)
    for (parameter_name, value_by_entity) in parameters
        _merge_parameter_data!(
            data, parameter_name, value_by_entity; for_object=for_object, report=report, alternative=alternative
        )
    end
    if isempty(comment)
        comment = string("Add $(join([string(k) for (k, v) in parameters])), automatically from SpineInterface.jl.")
    end
    if !isempty(alternative)
        alternatives = get!(data, :alternatives, [])
        push!(alternatives, [alternative])
    end
    count, errors = import_data(url, data, comment; upgrade=upgrade)
    isempty(errors) || @warn join(errors, "\n")
end
function write_parameters(parameter::Parameter, url::String, entities, fn=val->val; kwargs...)
    write_parameters(Dict(parameter.name => Dict(e => fn(parameter(; e...)) for e in entities)), url; kwargs...)
end

function _merge_parameter_data!(
    data::Dict{Symbol,Any},
    parameter_name::T,
    value_by_entity::Dict;
    for_object::Bool=true,
    report::String="",
    alternative::String=""
) where T
    pname = string(parameter_name)
    object_classes = get!(data, :object_classes, [])
    object_parameters = get!(data, :object_parameters, [])
    objects = get!(data, :objects, [])
    object_parameter_values = get!(data, :object_parameter_values, [])
    relationship_classes = get!(data, :relationship_classes, [])
    relationship_parameters = get!(data, :relationship_parameters, [])
    relationships = get!(data, :relationships, [])
    relationship_parameter_values = get!(data, :relationship_parameter_values, [])
    !isempty(report) && pushfirst!(object_classes, "report")
    for obj_cls_names in unique(_object_class_names(entity) for entity in keys(value_by_entity))
        append!(object_classes, obj_cls_names)
        !isempty(report) && pushfirst!(obj_cls_names, "report")
        if for_object && length(obj_cls_names) == 1
            obj_cls_name = obj_cls_names[1]
            push!(object_parameters, (obj_cls_name, pname))
        else
            rel_cls_name = join(obj_cls_names, "__")
            push!(relationship_classes, (rel_cls_name, obj_cls_names))
            push!(relationship_parameters, (rel_cls_name, pname))
        end
    end
    unique!(object_classes)
    !isempty(report) && pushfirst!(objects, ("report", report))
    for (entity, value) in value_by_entity
        obj_cls_names = _object_class_names(entity)
        obj_names = [string(x) for x in values(entity)]
        for (obj_cls_name, obj_name) in zip(obj_cls_names, obj_names)
            push!(objects, (obj_cls_name, obj_name))
        end
        if !isempty(report)
            pushfirst!(obj_cls_names, "report")
            pushfirst!(obj_names, report)
        end
        if for_object && length(obj_cls_names) == length(obj_names) == 1
            obj_cls_name = obj_cls_names[1]
            obj_name = obj_names[1]
            val = [obj_cls_name, obj_name, pname, unparse_db_value(value)]
            !isempty(alternative) && push!(val, alternative)
            push!(object_parameter_values, val)
        else
            rel_cls_name = join(obj_cls_names, "__")
            push!(relationships, (rel_cls_name, obj_names))
            val = [rel_cls_name, obj_names, pname, unparse_db_value(value)]
            !isempty(alternative) && push!(val, alternative)
            push!(relationship_parameter_values, val)
        end
    end
end

"""An `Array` with the object class names of an entity."""
_object_class_names(entity::NamedTuple) = [_object_class_name(key, val) for (key, val) in pairs(entity)]

_object_class_name(key, val::Object) = string(val.class_name !== nothing ? val.class_name : key)
_object_class_name(key, val) = string(key)

"""
    import_data(url, data, comment)

Import data to a Spine db.

# Arguments
- `url::String`: the url of the target database.
- `data::Dict`: the data to import, in the format below.
- `comment::String`: the commit message.

Format of the data Dict:
```
Dict(
    :object_classes => [:oc_name, ...],
    :relationship_classes => [[:rc_name, [:oc_name1, :oc_name2, ...]], ...],
    :objects => [[:oc_name, :obj_name], ...],
    :relationships => [[:rc_name, [:obj_name1, :obj_name2, ...], ...],
    :object_parameters => [[:oc_name, :param_name, default_value], ...],
    :relationship_parameters => [[:rc_name, :param_name, default_value], ...],
    :object_parameter_values => [[:oc_name, :obj_name, :param_name, value, :alt_name], ...],
    :relationship_parameter_values => [[:rc_name, [:obj_name1, :obj_name2, ...], :param_name, value, :alt_name], ...],
    :object_groups => [[:class_name, :group_name, :member_name], ...],
    :scenarios => [(:scen_name, true), ...],  # true for the active flag, not in use at the moment
    :alternatives => [:alt_name, ...],
    :scenario_alternatives => [(:scen_name, :alt_name, nothing), (:scen_name, :lower_alt_name, :alt_name), ...],
    :entity_alternatives => [
        [:object_class, :entity_name, :alt_name, true], ...
        [:multi_d_class, [:entity_name1, :entity_name2], :alt_name, false]
    ]
)
```

# Example
```
d = Dict(
    :object_classes => [:dog, :cat],
    :objects => [[:dog, :brian], [:dog, :spike]]
)
import_data(url, d, "arf!")
```
"""
function import_data(url, data::EntityClass, comment::String; upgrade=false)
    import_data(url, _to_dict(data), comment; upgrade=upgrade)
end
function import_data(url, data::Vector, comment::String; upgrade=false)
    import_data(url, merge(append!, _to_dict.(data)...), comment; upgrade=upgrade)
end
function import_data(url, data::Dict{String,T}, comment::String; upgrade=false) where {T}
    import_data(url, Dict(Symbol(k) => v for (k, v) in data), comment; upgrade=upgrade)
end
function import_data(url, comment::String; upgrade=false, kwargs...)
    import_data(url, Dict(Symbol(k) => v for (k, v) in pairs(kwargs)), comment; upgrade=upgrade)
end
function import_data(url, data::Dict{Symbol,T}, comment::String; upgrade=false) where {T}
    _db(url; upgrade=upgrade) do db
        _import_data(db, data, comment)
    end
end

"""
    export_data(url)

Export data from a Spine DB.
"""
function export_data(url; upgrade=false, filters=Dict())
    _db(url; upgrade=upgrade) do db
        _export_data(db; filters=filters)
    end
end

"""
    without_filters(f, url)

Run function f on given url without filters.
In other words: clear all filters, run function f, then restablish the previous filters.
"""
function without_filters(f, url)
    _db(url) do db
        old_filters = _current_filters(db)
        isempty(old_filters) && return f(db)
        _run_server_request(db, "clear_filters")
        try
            f(db)
        finally
            _run_server_request(db, "apply_filters", (old_filters,))
        end
    end
end

"""
    run_request(url::String, request::String, args, kwargs; upgrade=false)

Run the given request on the given url, using the given args.
"""
function run_request(url, request::String; upgrade=false)
    run_request(url, request, (), Dict(); upgrade=upgrade)
end
function run_request(url, request::String, args::Tuple; upgrade=false)
    run_request(url, request, args, Dict(); upgrade=upgrade)
end
function run_request(url, request::String, kwargs::Dict; upgrade=false)
    run_request(url, request, (), kwargs; upgrade=upgrade)
end
function run_request(url, request::String, args::Tuple, kwargs::Dict; upgrade=false)
    _db(url; upgrade=upgrade) do db
        _run_server_request(db, request, args, kwargs)
    end
end

function open_connection(db_url)
    _handlers[db_url] = _create_db_handler(db_url, false)
end

function close_connection(db_url)
    handler = pop!(_handlers, db_url, nothing)
    handler === nothing || _close_db_handler(handler)
end

_handlers = Dict()

function _db(f, url::String; upgrade=false)
    uri = URI(url)
    if uri.scheme == "http"
        f(uri)
    else
        handler = get(_handlers, url, nothing)
        if handler !== nothing
            f(handler)
        else
            handler = _create_db_handler(url, upgrade)
            result = f(handler)
            _close_db_handler(handler)
            result
        end
    end
end
_db(f, db; kwargs...) = f(db)

function _create_db_handler(db_url::String, upgrade::Bool)
    _import_spinedb_api()
    handler = Base.invokelatest(_do_create_db_handler, db_url, upgrade)
    atexit(() -> _close_db_handler(handler))
    handler
end

const _required_spinedb_api_version = v"0.31.0"
function _import_spinedb_api()
    isdefined(@__MODULE__, :db_api) && return
    @eval begin
        using PyCall
        const db_api, db_server = try
            pyimport("spinedb_api"), pyimport("spinedb_api.spine_db_server")
        catch err
            if err isa PyCall.PyError
                py = PyCall.pyprogramname
                indent = repeat(" ", 4)
                error(
                    "The required Python package `spinedb_api` could not be found ",
                    "in the current Python environment\n\n",
                    "$indent$python\n\n",
                    "You can fix this in two different ways:\n",
                    "A. Install `spinedb_api` in the current Python environment; ",
                    "open a terminal (command prompt on Windows) and run\n\n",
                    "$indent$python -m pip install --user ",
                    "'git+https://github.com/Spine-project/Spine-Database-API'\n\n",
                    "B. Switch to another Python environment that has `spinedb_api` installed; from Julia, run\n\n",
                    "$(indent)ENV[\"PYTHON\"] = \"... path of the python executable ...\"\n",
                    "$(indent)Pkg.build(\"PyCall\")\n\n",
                    "And restart Julia.\n",
                )
            else
                rethrow()
            end
        end
        spinedb_api_version = _parse_spinedb_api_version(db_api.__version__)
        if spinedb_api_version < _required_spinedb_api_version
            python = PyCall.pyprogramname
            indent = repeat(" ", 4)
            error(
                "The required version $_required_spinedb_api_version of `spinedb_api` could not be found ",
                "in the current Python environment\n\n",
                "$indent$python\n\n",
                "You can fix this in two different ways:\n",
                "A. Upgrade `spinedb_api` to its latest version in the current Python environment; ",
                "open a terminal (command prompt on Windows) and run\n\n",
                "$indent$python -m pip upgrade --user 'git+https://github.com/Spine-project/Spine-Database-API'\n\n",
                "B. Switch to another Python environment ",
                "that has `spinedb_api` version $_required_spinedb_api_version installed; from Julia, run\n\n",
                "$(indent)ENV[\"PYTHON\"] = \"... path of the python executable ...\"\n",
                "$(indent)Pkg.build(\"PyCall\")\n\n",
                "And restart Julia.",
            )
        end
    end
end

function _parse_spinedb_api_version(version)
    # Version number shortened and tweaked to avoid PEP 440 -> SemVer issues
    VersionNumber(replace(join(split(version, '.')[1:3],'.'), '-' => '+'))
end
_parse_spinedb_api_version(::Nothing) = VersionNumber(0)

_do_create_db_handler(db_url::String, upgrade::Bool) = db_server.DBHandler(db_url, upgrade)

_close_db_handler(handler) = Base.invokelatest(_do_close_db_handler, handler)

_do_close_db_handler(handler) = handler.close()

function _import_data(db, data::Dict{Symbol,T}, comment::String) where {T}
    _run_server_request(db, "import_data", (Dict(string(k) => v for (k, v) in data), comment))
end

function _export_data(db; filters=Dict())
    isempty(filters) && return _run_server_request(db, "export_data")
    old_filters = _current_filters(db)
    _run_server_request(db, "apply_filters", (filters,))
    data = _run_server_request(db, "export_data")
    _run_server_request(db, "clear_filters")
    isempty(old_filters) || _run_server_request(db, "apply_filters", (old_filters,))
    data
end

function _current_filters(db)
    Dict(
        k => v
        for (k, v) in merge!(Dict(), _run_server_request(db, "call_method", ("get_filter_configs",))...)
        if k in ("alternatives", "scenario", "tool")
    )
end

const _client_version = 8
const _EOT = '\u04'  # End of transmission
const _START_OF_TAIL = '\u1f'  # Unit separator
const _START_OF_ADDRESS = '\u91'  # Private Use 1
const _ADDRESS_SEP = ':'

function _run_server_request(db, request::String)
    _run_server_request(db, request, (), Dict())
end
function _run_server_request(db, request::String, args::Tuple)
    _run_server_request(db, request, args, Dict())
end
function _run_server_request(db, request::String, kwargs::Dict)
    _run_server_request(db, request, (), kwargs)
end
function _run_server_request(server_uri::URI, request::String, args::Tuple, kwargs::Dict)
    _do_run_server_request(server_uri, ["get_db_url", ()])  # to trigger compilation
    elapsed = @elapsed _do_run_server_request(server_uri, ["get_db_url", ()])
    spinedb_api_version = _do_run_server_request(server_uri, ["get_api_version", ()]; timeout=10 * elapsed)
    if _parse_spinedb_api_version(spinedb_api_version) < _required_spinedb_api_version
        error(
            "The required version $_required_spinedb_api_version of `spinedb_api` could not be found. ",
            "Please update Spine Toolbox by following the instructions at\n\n",
            "\thttps://github.com/Spine-project/Spine-Toolbox#installation\n\n",
        )
    end
    full_request = [request, args, kwargs, _client_version]
    _do_run_server_request(server_uri, full_request)
end
function _run_server_request(dbh, request::String, args::Tuple, kwargs::Dict)
    full_request = [request, args, kwargs, _client_version]
    request = Base.invokelatest(pybytes, _encode(full_request))
    io = IOBuffer()
    str = Base.invokelatest(_handle_request, dbh, request)
    write(io, str)
    answer = _decode(io)
    _process_db_answer(answer)
end

function _do_run_server_request(server_uri::URI, full_request::Array; timeout=Inf)
    clientside = connect(server_uri.host, parse(Int, server_uri.port))
    write(clientside, _encode(full_request))
    write(clientside, UInt8(_EOT))
    io = IOBuffer()
    elapsed = 0
    while true
        bytes = readavailable(clientside)
        if !isempty(bytes)
            write(io, bytes)
            elapsed = 0
            if bytes[end] == UInt8(_EOT)
                break
            end
            continue
        end
        if elapsed > timeout
            close(clientside)
            return
        end
        sleep(0.02)
        elapsed += 0.02
    end
    close(clientside)
    answer = _decode(io)
    isempty(answer) && return  # FIXME: needed?
    _process_db_answer(answer)
end

function _encode(obj)
    s = _TailSerialization()
    body = sprint(JSON.show_json, s, obj)
    vcat(Vector{UInt8}(body), UInt8(_START_OF_TAIL), s.tail)
end

struct _TailSerialization <: JSON.CommonSerialization
    tail::Vector{UInt8}
    _TailSerialization() = new(Vector{UInt8}())
end

function JSON.show_json(io::JSON.StructuralContext, s::_TailSerialization, bytes::Vector{UInt8})
    tip = length(s.tail)
    from, to = tip, tip + length(bytes) - 1  # 0-based
    marker = string(_START_OF_ADDRESS, from, _ADDRESS_SEP, to)
    append!(s.tail, bytes)
    JSON.show_json(io, JSON.StandardSerialization(), marker)
end

_handle_request(dbh, request) = dbh.handle_request(request)

function _decode(io)
    bytes = take!(io)
    i = findlast(bytes .== UInt8(_START_OF_TAIL))
    body, tail = bytes[1 : i - 1], bytes[i + 1 : end]
    o = JSON.parse(String(body))
    _expand_addresses!(o, tail)
end

function _expand_addresses!(o::Dict, tail)
    for (k, v) in o
        o[k] = _expand_addresses!(v, tail)
    end
    o
end
function _expand_addresses!(o::Array, tail)
    for (k, e) in enumerate(o)
        o[k] = _expand_addresses!(e, tail)
    end
    o
end
function _expand_addresses!(o::String, tail)
    startswith(o, _START_OF_ADDRESS) || return o
    marker = lstrip(o, _START_OF_ADDRESS)
    from, to = (parse(Int64, x) + 1 for x in split(marker, _ADDRESS_SEP))  # 1-based
    tail[from:to]
end
_expand_addresses!(o, tail) = o

function _process_db_answer(answer::Dict)
    result = get(answer, "result", nothing)
    err = get(answer, "error", nothing)
    _process_db_answer(result, err)
end
_process_db_answer(answer) = answer  # Legacy
_process_db_answer(result, err::Nothing) = result
function _process_db_answer(result, err::Int64)
    if err == 1
        required_client_version = result
        error(
            "version mismatch: DB server requires client version $required_client_version, ",
            "whereas current version is $_client_version; ",
            "please update SpineInterface"
        )
    else
        error("unknown error code $err returned by DB server")
    end
end
_process_db_answer(result, err) = error(string(err))

function _to_dict(obj_cls::ObjectClass)
    Dict(
        :object_classes => [obj_cls.name],
        :object_parameters => [
            [obj_cls.name, parameter_name, unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in obj_cls.parameter_defaults
        ],
        :objects => [[obj_cls.name, object.name] for object in obj_cls.objects],
        :object_parameter_values => [
            [obj_cls.name, object.name, parameter_name, unparse_db_value(parameter_value)]
            for (object, parameter_values) in obj_cls.parameter_values
            for (parameter_name, parameter_value) in parameter_values
        ]
    )
end
function _to_dict(rel_cls::RelationshipClass)
    Dict(
        :object_classes => unique(rel_cls.intact_object_class_names),
        :objects => unique(
            [obj_cls_name, obj.name]
            for relationship in rel_cls.relationships
            for (obj_cls_name, obj) in zip(rel_cls.intact_object_class_names, relationship)
        ),
        :relationship_classes => [[rel_cls.name, rel_cls.intact_object_class_names]],
        :relationship_parameters => [
            [rel_cls.name, parameter_name, unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in rel_cls.parameter_defaults
        ],
        :relationships => [
            [rel_cls.name, [obj.name for obj in relationship]] for relationship in rel_cls.relationships
        ],
        :relationship_parameter_values => [
            [rel_cls.name, [obj.name for obj in relationship], parameter_name, unparse_db_value(parameter_value)]
            for (relationship, parameter_values) in rel_cls.parameter_values
            for (parameter_name, parameter_value) in parameter_values
        ]
    )
end
