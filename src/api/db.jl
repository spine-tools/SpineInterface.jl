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

function label_and_dimensions(class_data)
    if length(class_data) > 1
        dimension_data = class_data[2]
        dimensions = !isempty(dimension_data) ? Tuple(Symbol(dimension) for dimension in dimension_data) : nothing
    else
        dimensions = nothing
    end
    Symbol(class_data[1]), dimensions
end
function label_and_dimensions(class_data::String)
    Symbol(class_data), nothing
end

function try_add_superclass!(superclasses, label, entity_class_graph, subclasses_by_superclass, object_classes, relationship_classes)
    subclasses = subclasses_by_superclass[label]
    if !all(MetaGraphsNext.haskey(entity_class_graph, subclass_label) for subclass_label in subclasses)
        return false
    end
    add_superclass!(entity_class_graph, label, subclasses...)
    push!(superclasses, Superclass(label, entity_class_graph, object_classes, relationship_classes))
    true
end

function make_entity_classes!(entity_class_graph::MetaGraphsNext.MetaGraph, entity_class_data, superclass_subclass_data, final_object_classes)
    object_classes = Dict{Symbol, ObjectClass}()
    relationship_classes = Dict{Symbol, RelationshipClass}()
    superclasses::Vector{Superclass} = []
    pending = [label_and_dimensions(class_data) for class_data in entity_class_data]
    subclasses_by_superclass = Dict{Symbol, Vector{Symbol}}()
    for (superclass_name, subclass_name) in superclass_subclass_data
        subclasses = get!(subclasses_by_superclass, Symbol(superclass_name)) do
            Vector{Symbol}()
        end
        push!(subclasses, Symbol(subclass_name))
    end
    while !isempty(pending)
        classes_missing_dimensions = []
        for class_data in pending
            (label, dimensions) = class_data
            if label in keys(subclasses_by_superclass)
                if !try_add_superclass!(superclasses, label, entity_class_graph, subclasses_by_superclass, object_classes, relationship_classes)
                    push!(classes_missing_dimensions, class_data)
                end
            elseif isnothing(dimensions)
                add_object_class!(entity_class_graph, label)
                object_classes[label] = ObjectClass(label, entity_class_graph, Dict())
            elseif all(MetaGraphsNext.haskey(entity_class_graph, dimension_label) for dimension_label in dimensions)
                add_relationship_class!(entity_class_graph, label, dimensions...)
                relationship_classes[label] = RelationshipClass(label, entity_class_graph, final_object_classes)
            else
                push!(classes_missing_dimensions, class_data)
            end
        end
        if length(classes_missing_dimensions) == length(pending)
            error("some entity dimension is missing or misnamed")
        end
        pending = classes_missing_dimensions
    end
    object_classes, relationship_classes, superclasses
end

function make_entities!(entity_class_graph::MetaGraphsNext.MetaGraph, entity_data)
    if isempty(entity_data) # Prevent a negative sizehint! 4 rows down.
        return nothing
    end
    nd_entities = Int[]
    sizehint!(nd_entities, length(entity_data) - 1)
    for (i, (class_name, name_data)) in enumerate(entity_data)
        if !isa(name_data, String)
            push!(nd_entities, i)
            continue
        end
        add_entity!(entity_class_graph, Symbol(class_name), Symbol(name_data))
    end
    for i in nd_entities
        (class_name, byname) = entity_data[i]
        class_label = Symbol(class_name)
        atomic_dimension_choices = entity_class_graph[class_label].atomic_dimension_choices
        atoms = Vector{Atom}(undef, length(atomic_dimension_choices))
        for (j, (dimension_choices, atom_name)) in enumerate(zip(atomic_dimension_choices, byname))
            atom_label = Symbol(atom_name)
            if length(dimension_choices) == 1
                atoms[j] = dimension_choices[1] => atom_label
            else
                found = false
                for dimension_label in dimension_choices
                    if atom_label in entity_class_graph[dimension_label].entities
                        atoms[j] = dimension_label => atom_label
                        found = true
                        break
                    end
                end
                if !found
                    error("no dimension found for $atom_label in $class_label")
                end
            end
        end
        add_entity!(entity_class_graph, class_label, atoms...)
    end
end

function make_entity_groups!(entity_class_graph::MetaGraphsNext.MetaGraph, entity_group_data)
    for (class_name, group_name, member_name) in entity_group_data
        add_entity_group_member!(entity_class_graph, Symbol(class_name), Symbol(group_name), Symbol(member_name))
    end
end

function make_parameter_definitions!(entity_class_graph::MetaGraphsNext.MetaGraph, entity_classes, parameter_definition_data)
    parameters = Dict{Symbol, Parameter}()
    for (class_name, parameter_name, default_value_bytes) in parameter_definition_data
        class_label = Symbol(class_name)
        parameter_label = Symbol(parameter_name)
        default_value = _try_parameter_value_from_db(
            default_value_bytes, "unable to parse default value of `$(parameter_label)` in $class_label"
        )
        add_parameter_definition!(entity_class_graph, class_label, parameter_label, default_value)
        parameter = get!(parameters, parameter_label) do
            Parameter(parameter_label, entity_class_graph)
        end
        push_class!(parameter, entity_classes[class_label])
    end
    values(parameters)
end

function resolve_relationship_label(vertex::RelationshipClassVertex, entity_byname)
    for relationship_label in vertex.entities
        atoms = RelationshipAtoms(vertex.relationship_graph, relationship_label)
        if all(atom.second == Symbol(byname) for (atom, byname) in zip(atoms, entity_byname))
            return relationship_label
        end
    end
    error("can't find relationship label for byname $entity_byname")
end

function target_entity_label(::ObjectClassVertex, entity_name::AbstractString)
    Symbol(entity_name)
end
function target_entity_label(class_vertex::RelationshipClassVertex, entity_byname)
    resolve_relationship_label(class_vertex, entity_byname)
end

function make_parameter_values!(entity_class_graph::MetaGraphsNext.MetaGraph, parameter_value_data)
    for (class_name, entity_data, parameter_name, value_bytes) in parameter_value_data
        class_label = Symbol(class_name)
        class_vertex = entity_class_graph[class_label]
        entity_label = target_entity_label(class_vertex, entity_data)
        get!(class_vertex.parameter_values, entity_label, Dict())[Symbol(parameter_name)] = _try_parameter_value_from_db(
            value_bytes, "unable to parse the value of `$(parameter_name)` for $entity_data in $class_name"
        )
    end
end

function _try_parameter_value_from_db(db_value, err_msg)
    try
        parameter_value(parse_db_value(db_value))
    catch e
        rethrow(ErrorException("$err_msg: $(sprint(showerror, e))"))
    end
end

function make_entity_class_map(object_classes, relationship_classes, superclasses)
    entity_classes::Dict{Symbol, EntityClass} = copy(object_classes)
    merge!(entity_classes, relationship_classes)
    for class in superclasses
        entity_classes[class.name] = class
    end
    entity_classes
end

function make_legacy_objects!(class::ObjectClass)
    for entity_label in class.vertex.entities
        class.objects[entity_label] = Object(entity_label, class.name)
    end
    for entity_label in MetaGraphsNext.labels(class.vertex.entity_group_graph)
        object = class.objects[entity_label]
        for group_label in groups(class.vertex.entity_group_graph, entity_label)
            push!(object.groups, class.objects[group_label])
        end
        for member_label in members(class.vertex.entity_group_graph, entity_label)
            push!(object.members, class.objects[member_label])
        end
    end
end

function _generate_convenience_functions(data, mod; filters=Dict(), extend=false)
    entity_class_data = get(data, "entity_classes") do
        vcat(get(data, "object_classes", []), get("relationship_classes", []))
    end
    superclass_subclass_data = get(data, "superclass_subclasses", [])
    entity_data = get(data, "entities") do
        vcat(get(data, "objects", []), get(data, "relationships", []))
    end
    entity_group_data = get(data, "entity_groups") do
        get(data, "object_groups", [])
    end
    parameter_definition_data = get(data, "parameter_definitions") do
        vcat(get(data, "object_parameters", []), get(data, "relationship_parameters", []))
    end
    parameter_value_data = get(data, "parameter_values") do
        vcat(get(data, "object_parameter_values", []), get(data, "relationship_parameter_values", []))
    end
    entity_class_graph = empty_entity_class_graph()
    existing_object_classes = _getproperty!(mod, :_spine_object_classes, Dict{Symbol,ObjectClass}())
    (new_object_classes, relationship_classes, superclasses) = make_entity_classes!(
        entity_class_graph,
        entity_class_data,
        superclass_subclass_data,
        existing_object_classes
        )
    make_entities!(entity_class_graph, entity_data)
    make_entity_groups!(entity_class_graph, entity_group_data)
    entity_classes = make_entity_class_map(new_object_classes, relationship_classes, superclasses)
    parameters = make_parameter_definitions!(entity_class_graph, entity_classes, parameter_definition_data)
    make_parameter_values!(entity_class_graph, parameter_value_data)
    existing_relationship_classes = _getproperty!(mod, :_spine_relationship_classes, Dict{Symbol,RelationshipClass}())
    existing_superclasses = _getproperty!(mod, :_spine_superclasses, Dict{Symbol, Superclass}())
    existing_parameters = _getproperty!(mod, :_spine_parameters, Dict{Symbol,Parameter}())
    if !extend
        empty!(existing_object_classes)
        empty!(existing_relationship_classes)
        empty!(existing_superclasses)
        empty!(existing_parameters)
    end
    for object_class in values(new_object_classes)
        make_legacy_objects!(object_class)
        _add_binding!(mod, existing_object_classes, object_class.name, object_class, extend)
    end
    for relationship_class in values(relationship_classes)
        _add_binding!(mod, existing_relationship_classes, relationship_class.name, relationship_class, extend)
    end
    for superclass in superclasses
        _add_binding!(mod, existing_superclasses, superclass.name, superclass, extend)
    end
    for parameter in parameters
        _add_binding!(mod, existing_parameters, parameter.name, parameter, extend)
    end
end

function _add_binding!(mod, dict, name, new, extend)
    current = try
        _getproperty!(mod, name, new)
    catch err
        err isa UndefVarError || rethrow()
        @warn "ignoring $name not defined in $mod"
        return
    end
    if isa(current, UndefSpineItem) # Specific to static `write_interface`
        dict[name] = new
        setproperty!(mod, name, new)
        return
    elseif !_same_type(current, new)
        @warn "ignoring $new because there is already a binding with that name in $mod"
        return
    end
    dict[name] = current
    current === new || _env_merge!(current, new, extend)
end

function _getproperty!(mod, name, default)
    _getproperty!(mod, name) do
        default
    end
end
function _getproperty!(f::Function, mod::Module, name)
    if !isdefined(mod, name)
        value = f()
        @eval mod begin
            const $name = $value
            export $name
        end
    end
    Base.invokelatest(getproperty, mod, name)
end
function _getproperty!(f::Function, bind::Bind, name)
    if hasproperty(bind, name)
        getproperty(bind, name)
    else
        setproperty!(bind, name, f())
    end
end

_same_type(current::T, new::T) where T = true
_same_type(current, new) = false

function _env_merge!(current, new, extend)
    env = _active_env()
    if haskey(current.env_dict, env) && extend
        merge!(current, new)
    else
        current.env_dict[env] = new.env_dict[env]
    end
end

function write_interface(io::IO, template)
    object_classes = get(template, "object_classes") do
        [x for x in get(template, "entity_classes", []) if isempty(x[2])]
    end
    relationship_classes = get(template, "relationship_classes") do
        [x for x in get(template, "entity_classes", []) if !isempty(x[2])]
    end
    param_defs = get(template, "parameter_definitions") do
        vcat(get(template, "object_parameters", []), get(template, "relationship_parameters", []))
    end
    object_class_names = sort!(first.(object_classes))
    relationship_class_names = sort!(first.(relationship_classes))
    parameter_names = sort!(unique!((x -> x[2]).(param_defs)))
    println(io, "# Convenience functors")
    println(io, "## Object classes")
    for name in object_class_names
        println(io, "$name = UndefSpineItem()")
    end
    println(io, "## Relationship classes")
    for name in relationship_class_names
        println(io, "$name = UndefSpineItem()")
    end
    println(io, "## Parameters")
    for name in parameter_names
        println(io, "$name = UndefSpineItem()")
    end
    println(io, "## Exports")
    println(io, "## Object classes")
    for name in object_class_names
        println(io, "export $name")
    end
    println(io, "## Relationship classes")
    for name in relationship_class_names
        println(io, "export $name")
    end
    println(io, "## Parameters")
    for name in parameter_names
        println(io, "export $name")
    end
    println(io, "## Lookup dicts")
    println(io, "_spine_object_classes = Dict{Symbol,ObjectClass}()")
    println(io, "_spine_relationship_classes = Dict{Symbol,RelationshipClass}()")
    println(io, "_spine_parameters = Dict{Symbol,Parameter}()")
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
function import_data(url, data::AbstractVector{EntityClass}, comment::String; upgrade=false)
    import_data(url, merge(append!, _to_dict.(data)...), comment; upgrade=upgrade)
end
function import_data(url, data::Bind, comment::String; upgrade=false)
    import_data(
        url,
        [x for x in values(getfield(data, :d)) if isa(x, EntityClass)],
        comment;
        upgrade=upgrade
    )
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
                local indent = repeat(" ", 4)
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
            local indent = repeat(" ", 4)
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
    pybytes = Base.invokelatest(getproperty, @__MODULE__, :pybytes)
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
            for (parameter_name, parameter_default_value) in obj_cls.vertex.parameter_defaults
        ],
        :objects => [[obj_cls.name, entity_label] for entity_label in obj_cls.vertex.entities],
        :object_parameter_values => [
            [obj_cls.name, entity_label, parameter_name, unparse_db_value(parameter_value)]
            for (entity_label, parameter_values) in obj_cls.vertex.parameter_values
            for (parameter_name, parameter_value) in parameter_values
        ]
    )
end
function _to_dict(rel_cls::RelationshipClass)
    object_classes = Iterators.flatten(rel_cls.vertex.atomic_dimension_choices)
    relationship_graph = rel_cls.vertex.relationship_graph
    objects = [[label.first, label.second] for label in MetaGraphsNext.labels(relationship_graph) if label isa Pair]
    Dict(
        :object_classes => unique(object_classes),
        :objects => objects,
        :relationship_classes => [[rel_cls.name, [label for label in Dimensions(rel_cls.entity_class_graph, rel_cls.name)]]],
        :relationship_parameters => [
            [rel_cls.name, parameter_name, unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in rel_cls.vertex.parameter_defaults
        ],
        :relationships => [
            [rel_cls.name, [atom.second for atom in RelationshipAtoms(relationship_graph, entity_label)]] for entity_label in rel_cls.vertex.entities
        ],
        :relationship_parameter_values => [
            [rel_cls.name, [atom.second for atom in RelationshipAtoms(relationship_graph, entity_label)], parameter_name, unparse_db_value(parameter_value)]
            for (entity_label, parameter_values) in rel_cls.vertex.parameter_values
            for (parameter_name, parameter_value) in parameter_values
        ]
    )
end
function _to_dict(sc::Superclass)
    Dict(
        :object_classes => [sc.name],
        :object_parameters => [ # Do Superclasses ever have object parameter defaults?
            [sc.name, parameter_name, unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in sc.vertex.parameter_defaults
        ],
        :superclass_subclasses => [
            [sc.name, sub]
            for sub in MetaGraphsNext.inneighbor_labels(sc.entity_class_graph, sc.name)
        ]
    )
end
