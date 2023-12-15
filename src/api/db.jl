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

function export_data(url; upgrade=false, filters=Dict())
    _db(url; upgrade=upgrade) do db
        _export_data(db; filters=filters)
    end
end

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
    objects_per_id = Dict((class_name, name) => Object(name, class_name) for (class_name, name) in objects)
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
function _objects_per_class(objects)
    d = Dict()
    sizehint!(d, length(objects))
    for (class_name, obj_name) in objects
        arr = get!(d, class_name) do
            arr = Any[]
            sizehint!(arr, length(objects))
            arr
        end
        push!(arr, obj_name)
    end
    d
end

"""
A Dict mapping class ids to an Array of entities in that class.
"""
function _relationships_per_class(relationships)
    d = Dict()
    sizehint!(d, length(relationships))
    for (class_name, obj_name_lst) in relationships
        arr_tup = get!(d, class_name) do
            arr_tup = Tuple(Any[] for _o in obj_name_lst)
            for arr in arr_tup
                sizehint!(arr, length(relationships))
            end
            arr_tup
        end
        for (arr, obj_name) in zip(arr_tup, obj_name_lst)
            push!(arr, obj_name)
        end
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

"""
A Dict mapping object class names to arguments.
"""
function _obj_args_per_class(classes, objs_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    Dict(
        Symbol(class[1]) => _obj_class_args(
            class, objs_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
        )
        for class in classes
    )
end

function _obj_class_args(class, objs_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    class_name, = class
    object_names = get(objs_per_cls, class_name, ())
    param_defs = get(param_defs_per_cls, class_name, ())
    (
        _obj_and_vals(class_name, object_names, full_objs_per_id, param_defs, param_vals_per_ent),
        _default_parameter_values(param_defs),
    )
end

function _obj_and_vals(class_name, object_names, full_objs_per_id, param_defs, param_vals_per_ent)
    param_vals = (
        Symbol(param_name) => _object_parameter_values(class_name, object_names, param_name, param_vals_per_ent)
        for (class_name, param_name) in param_defs
    )
    objects = Dict(
        Symbol(class_name) => ObjectLike[full_objs_per_id[class_name, obj_name] for obj_name in object_names]
    )
    DataFrame(; objects..., param_vals..., copycols=false)
end

"""
An Array of parameter values.
"""
function _object_parameter_values(class_name, object_names, param_name, param_vals_per_ent)
    vals_by_obj_name = (
        obj_name => get(param_vals_per_ent, (class_name, obj_name, param_name), missing) for obj_name in object_names
    )
    [
        _try_parameter_value_from_db(val, "unable to parse value of `$param_name` for `$entity_name`")
        for (entity_name, val) in vals_by_obj_name
    ]
end

"""
A Dict mapping relationship class names to arguments.
"""
function _rel_args_per_class(classes, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    Dict(
        Symbol(class[1]) => _rel_class_args(
            class, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent
        )
        for class in classes
    )
end

function _rel_class_args(class, rels_per_cls, full_objs_per_id, param_defs_per_cls, param_vals_per_ent)
    class_name, object_class_name_list = class
    object_names_tuple = get(rels_per_cls, class_name, Tuple([] for _k in object_class_name_list))
    param_defs = get(param_defs_per_cls, class_name, ())
    (
        Symbol.(object_class_name_list),
        _rels_and_vals(object_class_name_list, object_names_tuple, full_objs_per_id, param_defs, param_vals_per_ent),
        _default_parameter_values(param_defs),
    )
end

function _rels_and_vals(object_class_name_list, object_names_tuple, full_objs_per_id, param_defs, param_vals_per_ent)
    param_vals = (
        Symbol(param_name) => _relationship_parameter_values(
            class_name, object_names_tuple, param_name, param_vals_per_ent
        )
        for (class_name, param_name) in param_defs
    )
    relationships = OrderedDict(
        Symbol(fixed_class_name) => ObjectLike[
            full_objs_per_id[class_name, obj_name] for obj_name in object_names_tuple[k]
        ]
        for (k, (class_name, fixed_class_name)) in enumerate(
            zip(object_class_name_list, _fix_name_ambiguity(object_class_name_list))
        )
    )
    DataFrame(; relationships..., param_vals..., copycols=false)
end

"""
An Array of parameter values.
"""
function _relationship_parameter_values(class_name, object_names_tuple, param_name, param_vals_per_ent)
    all(isempty(x) for x in object_names_tuple) && return []
    vals_by_obj_name_lst = (
        obj_name_lst => get(param_vals_per_ent, (class_name, collect(obj_name_lst), param_name), missing)
        for obj_name_lst in zip(object_names_tuple...)
    )
    [
        _try_parameter_value_from_db(val, "unable to parse value of `$param_name` for `$obj_name_lst`")
        for (obj_name_lst, val) in vals_by_obj_name_lst
    ]
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

function _try_parameter_value_from_db(db_value, err_msg)
    try
        parameter_value(parse_db_value(db_value))
    catch e
        rethrow(ErrorException("$err_msg: $(sprint(showerror, e))"))
    end
end
_try_parameter_value_from_db(::Missing, _err_msg) = missing

"""
A Dict mapping parameter names to an Array of class names where the parameter is defined.
The Array of class names is sorted by decreasing number of dimensions in the class.
Note that for object classes, the number of dimensions is zero.
"""
function _class_names_per_parameter(object_classes, relationship_classes, param_defs)
    d = Dict()
    for (class_name,) in object_classes
        class_param_defs = get(param_defs, class_name, ())
        dim_count = 0
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

function _generate_convenience_functions(data, mod; filters, extend)
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
    objs_per_cls = _objects_per_class(objects)
    rels_per_cls = _relationships_per_class(relationships)
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
    spine_object_classes = _getproperty!(mod, :_spine_object_classes, Dict())
    spine_relationship_classes = _getproperty!(mod, :_spine_relationship_classes, Dict())
    spine_parameters = _getproperty!(mod, :_spine_parameters, Dict())
    if !extend
        # Remove current classes and parameters that are not in the new dataset
        for name in setdiff(keys(spine_object_classes), keys(args_per_obj_cls))
            pop!(spine_object_classes, name)
            @eval mod $name = nothing
        end
        for name in setdiff(keys(spine_relationship_classes), keys(args_per_rel_cls))
            pop!(spine_relationship_classes, name)
            @eval mod $name = nothing
        end
        for name in setdiff(keys(spine_parameters), keys(class_names_per_param))
            pop!(spine_parameters, name)
            @eval mod $name = nothing
        end
    end
    # Create new
    for (name, args) in args_per_obj_cls
        spine_object_classes[name] = new = ObjectClass(name, args...)
        @eval mod begin
            $name = $new
            export $name
        end
    end
    for (name, args) in args_per_rel_cls
        spine_relationship_classes[name] = new = RelationshipClass(name, args...)
        @eval mod begin
            $name = $new
            export $name
        end
    end
    for (name, class_names) in class_names_per_param
        classes = [getfield(mod, x) for x in class_names]
        spine_parameters[name] = new = Parameter(name, classes)
        @eval mod begin
            $name = $new
            export $name
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
  - `alternative::String`: an alternative to pass to `SpineInterface.write_parameters`.
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
function _object_class_name(key, val::ObjectLike)
    try
        _object_class_name(key, val, val.class_name)
    catch
        _object_class_name(key, val, Symbol(val))
    end
end
_object_class_name(key, val::ObjectLike, class_name::Symbol) = string(class_name)
_object_class_name(key, val::ObjectLike, ::Nothing) = string(key)
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
    :scenario_alternatives => [(:scen_name, :alt_name, nothing), (:scen_name, :lower_alt_name, :alt_name), ...]
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
function import_data(url::String, data::Union{ObjectClass,RelationshipClass}, comment::String; upgrade=false)
    import_data(url, _to_dict(data), comment; upgrade=upgrade)
end
function import_data(url::String, data::Vector, comment::String; upgrade=false)
    import_data(url, merge(append!, _to_dict.(data)...), comment; upgrade=upgrade)
end
function import_data(url::String, data::Dict{String,T}, comment::String; upgrade=false) where {T}
    import_data(url, Dict(Symbol(k) => v for (k, v) in data), comment; upgrade=upgrade)
end
function import_data(url::String, comment::String; upgrade=false, kwargs...)
    import_data(url, Dict(Symbol(k) => v for (k, v) in pairs(kwargs)), comment; upgrade=upgrade)
end
function import_data(url::String, data::Dict{Symbol,T}, comment::String; upgrade=false) where {T}
    _db(url; upgrade=upgrade) do db
        _import_data(db, data, comment)
    end
end

"""
    run_request(url::String, request::String, args, kwargs; upgrade=false)

Run the given request on the given url, using the given args.
"""
function run_request(url::String, request::String; upgrade=false)
    run_request(url, request, (), Dict(); upgrade=upgrade)
end
function run_request(url::String, request::String, args::Tuple; upgrade=false)
    run_request(url, request, args, Dict(); upgrade=upgrade)
end
function run_request(url::String, request::String, kwargs::Dict; upgrade=false)
    run_request(url, request, (), kwargs; upgrade=upgrade)
end
function run_request(url::String, request::String, args::Tuple, kwargs::Dict; upgrade=false)
    _db(url; upgrade=upgrade) do db
        _run_request(db, request, args, kwargs)
    end
end

function open_connection(db_url)
    _handlers[db_url] = _create_db_handler(db_url, false)
end

function close_connection(db_url)
    handler = pop!(_handlers, db_url, nothing)
    handler === nothing || _close_db_handler(handler)
end

function _parse_spinedb_api_version(version)
    # Version number shortened and tweaked to avoid PEP 440 -> SemVer issues
    VersionNumber(replace(join(split(version, '.')[1:3],'.'), '-' => '+'))
end
_parse_spinedb_api_version(::Nothing) = VersionNumber(0)

function _import_spinedb_api()
    isdefined(@__MODULE__, :db_api) && return
    @eval begin
        using PyCall
        const db_api, db_server = try
            pyimport("spinedb_api"), pyimport("spinedb_api.spine_db_server")
        catch err
            if err isa PyCall.PyError
                error(_spinedb_api_not_found(PyCall.pyprogramname))
            else
                rethrow()
            end
        end
        spinedb_api_version = _parse_spinedb_api_version(db_api.__version__)
        if spinedb_api_version < _required_spinedb_api_version
            error(_required_spinedb_api_version_not_found_py_call(PyCall.pyprogramname))
        end
    end
end

_handlers = Dict()

_do_create_db_handler(db_url::String, upgrade::Bool) = db_server.DBHandler(db_url, upgrade)

_do_close_db_handler(handler) = handler.close()

function _create_db_handler(db_url::String, upgrade::Bool)
    _import_spinedb_api()
    handler = Base.invokelatest(_do_create_db_handler, db_url, upgrade)
    atexit(() -> _close_db_handler(handler))
    handler
end

_close_db_handler(handler) = Base.invokelatest(_do_close_db_handler, handler)

function _db(f, url; upgrade=false)
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

function _encode(obj)
    s = _TailSerialization()
    body = sprint(JSON.show_json, s, obj)
    vcat(Vector{UInt8}(body), UInt8(_START_OF_TAIL), s.tail)
end

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

_handle_request(dbh, request) = dbh.handle_request(request)

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
        error(_required_spinedb_api_version_not_found_server)
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

function _export_data(db; filters=Dict())
    isempty(filters) && return _run_server_request(db, "export_data")
    old_filters = Dict(
        k => v
        for (k, v) in merge!(Dict(), _run_server_request(db, "call_method", ("get_filter_configs",))...)
        if k in ("alternatives", "scenario", "tool")
    )
    _run_server_request(db, "apply_filters", (filters,))
    data = _run_server_request(db, "export_data")
    _run_server_request(db, "clear_filters")
    isempty(old_filters) || _run_server_request(db, "apply_filters", (old_filters,))
    data
end

function _import_data(db, data::Dict{Symbol,T}, comment::String) where {T}
    _run_server_request(db, "import_data", (Dict(string(k) => v for (k, v) in data), comment))
end

function _run_request(db, request::String, args::Tuple, kwargs::Dict)
    _run_server_request(db, request, args, kwargs)
end

function _to_dict(obj_cls::ObjectClass)
    Dict(
        :object_classes => [obj_cls.name],
        :object_parameters => [
            [obj_cls.name, parameter_name, unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in obj_cls.default_parameter_values
        ],
        :objects => [[obj_cls.name, object.name] for object in obj_cls.entities[!, obj_cls.name]],
        :object_parameter_values => [
            [obj_cls.name, row[obj_cls.name].name, p_name, unparse_db_value(p_val)]
            for row in eachrow(obj_cls.entities)
            for (p_name, p_val) in pairs(row)
            if p_name != obj_cls.name && p_val !== missing
        ]
    )
end
function _to_dict(rel_cls::RelationshipClass)
    Dict(
        :object_classes => unique(rel_cls.intact_object_class_names),
        :objects => unique(
            [obj_cls_name, obj.name]
            for row in eachrow(rel_cls.entities)
            for (obj_cls_name, obj) in zip(rel_cls.intact_object_class_names, row)
        ),
        :relationship_classes => [[rel_cls.name, rel_cls.intact_object_class_names]],
        :relationship_parameters => [
            [rel_cls.name, parameter_name, unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in rel_cls.default_parameter_values
        ],
        :relationships => [
            [rel_cls.name, [obj.name for obj in row]]
            for row in eachrow(rel_cls.entities[!, _object_class_names(rel_cls)])
        ],
        :relationship_parameter_values => [
            [
                rel_cls.name,
                [row[cls_name].name for cls_name in _object_class_names(rel_cls)],
                p_name,
                unparse_db_value(p_val)
            ]
            for row in eachrow(rel_cls.entities)
            for (p_name, p_val) in pairs(row)
            if !(p_name in _object_class_names(rel_cls)) && p_val !== missing
        ]
    )
end
