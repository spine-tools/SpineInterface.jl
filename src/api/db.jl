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

See [`EntityClass()`](@ref) and [`Parameter()`](@ref) for details on
how to call the convenience functors.
"""
function using_spinedb(url::String, mod=@__MODULE__; upgrade=false, filters=Dict(), extend=false)
    data = get_data(url; upgrade=upgrade, filters=filters)
    _generate_convenience_functions(data, mod; extend=extend)
end
function using_spinedb(template::Dict{Symbol,T}, mod=@__MODULE__; filters=nothing, extend=false) where T
    using_spinedb(Dict(string(key) => value for (key, value) in template), mod; filters=filters, extend=extend)
end
function using_spinedb(template::Dict{String,T}, mod=@__MODULE__; filters=nothing, extend=false) where T
    _generate_convenience_functions(template, mod; extend=extend)
end

"""
A Dict mapping entity group ids to an Array of member ids.
"""
function _members_per_group(data::Dict{String,Vector{Any}})
    entity_groups = data["entity_group"]
    d = Dict{Int64,Vector{Int64}}()
    for group in entity_groups
        push!(get!(d, group["entity_id"], []), group["member_id"])
    end
    return d
end

"""
A Dict mapping member ids to an Array of entity group ids.
"""
function _groups_per_member(data::Dict{String,Vector{Any}})
    entity_groups = data["entity_group"]
    d = Dict{Int64,Vector{Int64}}()
    for group in entity_groups
        push!(get!(d, group["member_id"], []), group["entity_id"])
    end
    d
end

"""
Return the list of "byelemenents" (aka leaf elements) for a given [`Entity`](@ref).
"""
function _recursive_byelement_list(entity::Entity)
    isempty(entity.element_list) && return [entity]
    byelement_list = vcat(_recursive_byelement_list.(entity.element_list)...)
    return byelement_list
end

"""
A Dict mapping entity ids to the corresponding [`Entity`](@ref).
"""
function _full_entities_per_id(
    data::Dict{String,Vector{Any}},
    members_per_group::Dict{Int64,Vector{Int64}},
    groups_per_member::Dict{Int64,Vector{Int64}}
)
    entities = data["entity"]
    entities_per_id = Dict{Int64,Entity}(
        ent["id"] => Entity(ent["name"], ent["entity_class_name"])
        for ent in entities
    )
    # Specify `element_list` for each entity
    for ent in entities
        append!(
            entities_per_id[ent["id"]].element_list,
            [entities_per_id[id] for id in ent["element_id_list"]]
        )
    end
    for (id, entity) in entities_per_id
        # Specify `members` for each group
        member_ids = get(members_per_group, id, [])
        !isempty(member_ids) && append!(
            entity.members, [entities_per_id[id] for id in member_ids]
        )
        # Specify `groups` for each member
        group_ids = get(groups_per_member, id, [])
        !isempty(group_ids) && append!(
            entity.groups, [entities_per_id[id] for id in group_ids]
        )
        # Specify `byelement_list` for each entity
        append!(entity.byelement_list, _recursive_byelement_list(entity))
    end
    entities_per_id
end

"""
A Dict mapping entity class ids to an Array of entity ids in that class.
"""
function _entity_ids_per_class(data::Dict{String,Vector{Any}})
    entities = data["entity"]
    d = Dict{Int64,Vector{Int64}}()
    for ent in entities
        push!(get!(d, ent["class_id"], []), ent["id"])
    end
    d
end

DBParseLike = Union{Vector{UInt8},Nothing}
DBTypeLike = Union{String,Nothing}
DBParVal = Tuple{DBParseLike,DBTypeLike}
DBParDef = Tuple{String,String,DBParVal,DBTypeLike,DBTypeLike}

"""
A Dict mapping entity class ids to an Array of parameter definitions associated to that class.
"""
function _parameter_definitions_per_class(data::Dict{String,Vector{Any}})
    param_defs = data["parameter_definition"]
    d = Dict{Int64,Vector{DBParDef}}()
    for param_def in param_defs
        push!(
            get!(d, param_def["entity_class_id"], []),
            (
                param_def["entity_class_name"],
                param_def["name"],
                (param_def["default_value"], param_def["default_type"]),
                param_def["parameter_value_list_name"],
                param_def["description"]
            )
        )
    end
    d
end

"""
A Dict mapping entity ids to its parameter values.
"""
function _parameter_values_per_entity(data::Dict{String,Vector{Any}})
    param_values = data["parameter_value"]
    d = Dict{Int64,Vector{Tuple{String,DBParVal}}}()
    for param in param_values
        push!(
            get!(d, param["entity_id"], []),
            (
                param["parameter_definition_name"],
                (param["value"], param["type"])
            )
        )
    end
    d
end

function _try_parameter_value_from_db(db_value::DBParVal, err_msg::String)
    try
        parameter_value(parse_db_value(db_value))
    catch e
        rethrow(ErrorException("$err_msg: $(sprint(showerror, e))"))
    end
end



"""
A Dict mapping parameter names to their default values.
"""
function _default_parameter_values(param_defs::Vector{DBParDef})
    Dict{Symbol,ParameterValue}(
        Symbol(param_name) => _try_parameter_value_from_db(
            default_val, "unable to parse default value of `$(param_name)`"
        )
        for (class_name, param_name, default_val) in param_defs
    )
end

"""
A Dict mapping parameter names to their values for a given entity.
"""
function _parameter_values(
    entity_name::String,
    param_vals_for_ent::Vector{Tuple{String,DBParVal}}
)
    Dict{Symbol,ParameterValue}(
        Symbol(param_name) => _try_parameter_value_from_db(
            value, "unable to parse value of `$param_name` for `$entity_name`"
        )
        for (param_name, value) in param_vals_for_ent
    )
end

function _ents_and_vals(
    entity_ids::Vector{Int64},
    full_ents_per_id::Dict{Int64, Entity},
    param_vals_per_ent::Dict{Int64,Vector{Tuple{String,DBParVal}}}
)
    entity_ids_with_params = intersect(entity_ids, keys(param_vals_per_ent))
    entities_with_params = zip(
        entity_ids_with_params,
        [full_ents_per_id[id] for id in entity_ids_with_params]
    )
    param_vals = Dict(
        (ent.byelement_list...,) => _parameter_values(string(ent.name), param_vals_per_ent[id])
        for (id, ent) in entities_with_params
    )
    param_vals
end

function _ent_class_args(
    class_id::Int64,
    dimension_name_list::Vector{Any}, # This can be empty, no strict typing
    ents_per_cls::Dict{Int64,Vector{Int64}},
    full_ents_per_id::Dict{Int64,Entity},
    param_defs_per_cls::Dict{Int64,Vector{DBParDef}},
    param_vals_per_ent::Dict{Int64,Vector{Tuple{String,DBParVal}}}
)
    entity_ids = get(ents_per_cls, class_id, Vector{Int64}())
    param_defs = get(param_defs_per_cls, class_id, Vector{DBParDef}())
    (
        Symbol.(dimension_name_list),
        [full_ents_per_id[id] for id in entity_ids],
        _ents_and_vals(entity_ids, full_ents_per_id, param_vals_per_ent),
        _default_parameter_values(param_defs),
    )
end

"""
A Dict mapping entity class names to arguments.
"""
function _ent_args_per_class(
    data::Dict{String,Vector{Any}},
    ents_per_cls::Dict{Int64,Vector{Int64}},
    full_ents_per_id::Dict{Int64,Entity},
    param_defs_per_cls::Dict{Int64,Vector{DBParDef}},
    param_vals_per_ent::Dict{Int64,Vector{Tuple{String,DBParVal}}}
)
    classes = data["entity_class"]
    Dict{Symbol,Tuple{Vector,Vector{Entity},Dict,Dict}}(
        Symbol(cls["name"]) => _ent_class_args(
            cls["id"],
            cls["dimension_name_list"],
            ents_per_cls,
            full_ents_per_id,
            param_defs_per_cls,
            param_vals_per_ent
        )
        for cls in classes
    )
end

"""
A Dict mapping parameter names to an Array of class names where the parameter is defined.
The Array of class names is sorted by decreasing number of dimensions in the class.
Note that for object classes, the number of dimensions is one.
"""
function _class_names_per_parameter(
    data::Dict{String,Vector{Any}},
    param_defs_per_cls::Dict{Int64,Vector{DBParDef}}
)
    raw_param_defs = data["parameter_definition"]
    d = Dict{Symbol,Vector{Tuple{Symbol,Int64}}}()
    for def in raw_param_defs
        class_param_defs = param_defs_per_cls[def["entity_class_id"]]
        for (class_name, parameter_name) in class_param_defs
            push!(
                get!(d, Symbol(parameter_name), Tuple{Symbol,Int64}[]),
                (Symbol(class_name), length(def["dimension_name_list"]))
            )
        end
    end
    Dict{Symbol,Vector{Symbol}}(
        name => first.(sort(tups; by=last, rev=true)) for (name, tups) in d
    )
end

function _generate_convenience_functions(
    data::Dict{String,Vector{Any}}, mod::Module; extend::Bool=false
)
    # Fetch and create entities, organize them by "id" (class, name) and class.
    members_per_group = _members_per_group(data)
    groups_per_member = _groups_per_member(data)
    full_entities_per_id = _full_entities_per_id(data, members_per_group, groups_per_member)
    entity_ids_per_class = _entity_ids_per_class(data)
    # Fetch and organise parameter definitions and values.
    param_defs_per_cls = _parameter_definitions_per_class(data)
    param_vals_per_ent = _parameter_values_per_entity(data)
    # Organise arguments for EntityClass creation
    args_per_ent_cls = _ent_args_per_class(
        data, entity_ids_per_class, full_entities_per_id, param_defs_per_cls, param_vals_per_ent
    )
    # Organise arguments for Parameter creation
    class_names_per_param = _class_names_per_parameter(data, param_defs_per_cls)
    # Get or create Spine data structure containers
    spine_entity_classes = _getproperty!(mod, :_spine_entity_classes, Dict())
    spine_parameters = _getproperty!(mod, :_spine_parameters, Dict())
    if !extend
        env = _active_env()
        for elements in (spine_entity_classes, spine_parameters)
            for (name, x) in collect(elements)
                if isempty(delete!(x.env_dict, env))
                    pop!(elements, name)
                    @eval mod $name = nothing
                end
            end
        end
    end
    # Create the convenience functions and eval them to the desired scope.
    for (name, args) in args_per_ent_cls
        new = EntityClass(name, args...; mod=mod, extend=extend)
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

_object_class_name(key, val::Entity) = string(val.class_name !== nothing ? val.class_name : key)
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
    _get_data(url::String, upgrade::Bool)

Get data from a Spine DB.

`upgrade` can be used to control whether DB upgrading is triggered.
See also [`get_data`](@ref).
"""
function _get_data(url::String, upgrade::Bool)
    _db(url; upgrade=upgrade) do db
        Dict(
            key => _run_server_request(db, "call_method", ("get_items", key))
            for key in [
                "entity_class",
                "entity",
                "entity_group",
                "parameter_definition",
                "parameter_value",
                "superclass_subclass"
            ]
        )
    end
end

"""
    get_data(url::String; upgrade=false, filters=Dict())

Get data from a Spine DB.

`upgrade` can be used to control whether DB upgrading is triggered, `false` by default.
`filters` can be used to apply filtering to the DB.
"""
function get_data(url::String; upgrade=false, filters=Dict())
    isempty(filters) && return _get_data(url, upgrade)
    old_filters = _current_filters(db)
    _run_server_request(db, "apply_filters", (filters,))
    data = _get_data(url, upgrade)
    _run_server_request(db, "clear_filters")
    isempty(old_filters) || _run_server_request(db, "apply_filters", (old_filters,))
    return data
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
    indent = repeat(" ", 4)

    _spinedb_api_not_found_error(pyprogramname) = error(
        "The required Python package `spinedb_api` could not be found in the current Python environment\n\n",
        "$indent$pyprogramname\n\n",
        "You can fix this in two different ways:\n",
        "A. Install `spinedb_api` in the current Python environment; ",
        "open a terminal (command prompt on Windows) and run\n\n",
        "$indent$pyprogramname -m pip install --user 'git+https://github.com/Spine-project/Spine-Database-API'\n\n",
        "B. Switch to another Python environment that has `spinedb_api` installed; from Julia, run\n\n",
        "$(indent)ENV[\"PYTHON\"] = \"... path of the python executable ...\"\n",
        "$(indent)Pkg.build(\"PyCall\")\n\n",
        "And restart Julia.\n",
    )

    _required_spinedb_api_version_not_found_py_call_error(pyprogramname) = error(
        "The required version $_required_spinedb_api_version of `spinedb_api` could not be found ",
        "in the current Python environment\n\n",
        "$indent$pyprogramname\n\n",
        "You can fix this in two different ways:\n",
        "A. Upgrade `spinedb_api` to its latest version in the current Python environment; ",
        "open a terminal (command prompt on Windows) and run\n\n",
        "$indent$pyprogramname -m pip upgrade --user 'git+https://github.com/Spine-project/Spine-Database-API'\n\n",
        "B. Switch to another Python environment ",
        "that has `spinedb_api` version $_required_spinedb_api_version installed; from Julia, run\n\n",
        "$(indent)ENV[\"PYTHON\"] = \"... path of the python executable ...\"\n",
        "$(indent)Pkg.build(\"PyCall\")\n\n",
        "And restart Julia.",
    )

    isdefined(@__MODULE__, :db_api) && return
    @eval begin
        using PyCall
        const db_api, db_server = try
            pyimport("spinedb_api"), pyimport("spinedb_api.spine_db_server")
        catch err
            if err isa PyCall.PyError
                _spinedb_api_not_found_error(PyCall.pyprogramname)
            else
                rethrow()
            end
        end
        spinedb_api_version = _parse_spinedb_api_version(db_api.__version__)
        if spinedb_api_version < _required_spinedb_api_version
            _required_spinedb_api_version_not_found_py_call_error(PyCall.pyprogramname)
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

function _to_dict(obj_cls::EntityClass)
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
function _to_dict(rel_cls::EntityClass)
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
