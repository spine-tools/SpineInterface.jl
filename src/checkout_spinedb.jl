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

function checkout_spinedb_parameter(db_map::PyObject, object_dict::Dict, relationship_dict::Dict, parse_value)
    parameter_dict = Dict()
    class_object_subset_dict = Dict{Symbol,Any}()
    object_parameter_value_dict =
        py"{(x.parameter_id, x.object_name): x.value for x in $db_map.object_parameter_value_list()}"
    relationship_parameter_value_dict =
        py"{(x.parameter_id, x.object_name_list): x.value for x in $db_map.relationship_parameter_value_list()}"
    value_list_dict = py"{x.id: x.value_list.split(',') for x in $db_map.wide_parameter_value_list_list()}"
    for parameter in py"[x._asdict() for x in $db_map.object_parameter_list()]"
        parameter_name = parameter["parameter_name"]
        parameter_id = parameter["id"]
        object_class_name = parameter["object_class_name"]
        tag_list = parameter["parameter_tag_list"]
        value_list_id = parameter["value_list_id"]
        tags = if tag_list isa String
            Dict(Symbol(x) => true for x in split(tag_list, ","))
        else
            Dict()
        end
        if value_list_id != nothing
            d1 = get!(class_object_subset_dict, Symbol(object_class_name), Dict{Symbol,Any}())
            object_subset_dict = get!(d1, Symbol(parameter_name), Dict{Symbol,Any}())
            for value in value_list_dict[value_list_id]
                object_subset_dict[Symbol(JSON.parse(value))] = Array{Symbol,1}()
            end
        end
        json_default_value = try
            JSON.parse(parameter["default_value"])
        catch e
            error("unable to parse default value of '$parameter_name': $(sprint(showerror, e))")
        end
        class_parameter_value_dict = get!(parameter_dict, Symbol(parameter_name), Dict{Tuple,Any}())
        parameter_value_dict = class_parameter_value_dict[(Symbol(object_class_name),)] = Dict{Tuple,Any}()
        for object_name in object_dict[object_class_name]
            value = get(object_parameter_value_dict, (parameter_id, object_name), nothing)
            if value == nothing
                json_value = nothing
            else
                json_value = JSON.parse(value)
            end
            symbol_object_name = Symbol(object_name)
            new_value = try
                parse_value(json_value; default=json_default_value, tags...)
            catch e
                error("unable to parse value of '$parameter_name' for '$object_name': $(sprint(showerror, e))")
            end
            parameter_value_dict[(symbol_object_name,)] = new_value
            # Add entry to class_object_subset_dict
            value_list_id == nothing && continue
            if haskey(object_subset_dict, Symbol(json_value))
                arr = object_subset_dict[Symbol(json_value)]
                push!(arr, symbol_object_name)
            else
                @warn string(
                    "the value of '$parameter_name' for '$symbol_object_name' is $json_value",
                    "which is not a listed value."
                )
            end
        end
    end
    for parameter in py"[x._asdict() for x in $db_map.relationship_parameter_list()]"
        parameter_name = parameter["parameter_name"]
        parameter_id = parameter["id"]
        relationship_class_name = parameter["relationship_class_name"]
        object_class_name_list = parameter["object_class_name_list"]
        tag_list = parameter["parameter_tag_list"]
        tags = if tag_list isa String
            Dict(Symbol(x) => true for x in split(tag_list, ","))
        else
            Dict()
        end
        json_default_value = try
            JSON.parse(parameter["default_value"])
        catch e
            error("unable to parse default value of '$parameter_name': $(sprint(showerror, e))")
        end
        class_parameter_value_dict = get!(parameter_dict, Symbol(parameter_name), Dict{Tuple,Any}())
        class_name = tuple(fix_name_ambiguity(Symbol.(split(object_class_name_list, ",")))...)
        if getkeyperm(class_parameter_value_dict, class_name, nothing) != nothing
            @warn(
                "'$parameter_name' is ambiguous"
                * " - use `$parameter_name($relationship_class_name=(...))` to access it."
            )
            alt_class_name = (Symbol(relationship_class_name),)
            parameter_value_dict = class_parameter_value_dict[alt_class_name] = Dict{Tuple,Any}()
        else
            # NOTE: with this, the first one gets the place alright - is that ok?
            parameter_value_dict = class_parameter_value_dict[class_name] = Dict{Tuple,Any}()
        end
        # Loop through all parameter values
        object_name_lists = relationship_dict[relationship_class_name]["object_name_lists"]
        for object_name_list in object_name_lists
            value = get(relationship_parameter_value_dict, (parameter_id, object_name_list), nothing)
            if value == nothing
                json_value = nothing
            else
                json_value = JSON.parse(value)
            end
            symbol_object_name_list = tuple(Symbol.(split(object_name_list, ","))...)
            new_value = try
                parse_value(json_value; default=json_default_value, tags...)
            catch e
                error(
                    "unable to parse value of '$parameter_name' for '$symbol_object_name_list': "
                    * "$(sprint(showerror, e))"
                )
            end
            parameter_value_dict[symbol_object_name_list] = new_value
        end
    end
    for (parameter_name, class_parameter_value_dict) in parameter_dict
        @suppress_err begin
            # Create and export convenience functions
            @eval begin
                """
                    $($parameter_name)(;kwargs...)

                The value of the parameter '$($parameter_name)' for the tuple given by `kwargs`.
                """
                function $(parameter_name)(;kwargs...)
                    class_parameter_value_dict = $(class_parameter_value_dict)
                    if length(kwargs) == 0
                        # Return dict if kwargs is empty
                        class_parameter_value_dict
                    else
                        class_names = keys(kwargs)
                        key = getkeyperm(class_parameter_value_dict, class_names, nothing)
                        key == nothing && error("'$($parameter_name)' not defined for class(es) '$class_names'")
                        parameter_value_dict = class_parameter_value_dict[key]
                        object_names = values(kwargs)
                        matched_object_names = Tuple([object_names[k] for k in key])
                        haskey(parameter_value_dict, matched_object_names) || error(
                            "'$($parameter_name)' not specified for '$object_names'"
                        )
                        parameter_value_dict[matched_object_names]
                    end
                end
                export $(parameter_name)
            end
        end
    end
    class_object_subset_dict
end


function checkout_spinedb_object(db_map::PyObject, object_dict::Dict, class_object_subset_dict::Dict{Symbol,Any})
    for (object_class_name, object_names) in object_dict
        symbol_object_names = Symbol.(object_names)
        object_subset_dict = get(class_object_subset_dict, Symbol(object_class_name), Dict())
        @suppress_err begin
            @eval begin
                # Create convenience function named after the object class
                function $(Symbol(object_class_name))(;kwargs...)
                    if length(kwargs) == 0
                        # Return all object names if kwargs is empty
                        return $(symbol_object_names)
                    else
                        object_class_name = $(object_class_name)
                        # Return the object subset at the intersection of all (parameter, value) pairs
                        # received as arguments
                        kwargs_arr = [par => val for (par, val) in kwargs]
                        par, val = kwargs_arr[1]
                        dict1 = $(object_subset_dict)
                        !haskey(dict1, par) && error(
                            "unable to retrieve object subset of class '$object_class_name': "
                            * "'$par' is not a list-parameter for '$object_class_name'"
                        )
                        dict2 = dict1[par]
                        !haskey(dict2, val) && error(
                            "unable to retrieve object subset of class '$object_class_name': "
                            * "'$val' is not a listed value for '$par'"
                        )
                        object_subset = dict2[val]
                        for (par, val) in kwargs_arr[2:end]
                            !haskey(dict1, par) && error(
                                "unable to retrieve object subset of class '$object_class_name': "
                                * "'$par' is not a list-parameter for '$object_class_name'"
                            )
                            dict2 = dict1[par]
                            !haskey(dict2, val) && error(
                                "unable to retrieve object subset of class '$object_class_name': "
                                * "'$val' is not a listed value for '$par'"
                            )
                            object_subset_ = dict2[val]
                            object_subset = [x for x in object_subset if x in object_subset_]
                        end
                        return object_subset
                    end
                end
                export $(Symbol(object_class_name))
            end
        end
    end
end


function checkout_spinedb_relationship(db_map::PyObject, relationship_dict::Dict)
    for (rel_cls_name, rel_cls) in relationship_dict
        obj_name_lists = [Symbol.(split(y, ",")) for y in rel_cls["object_name_lists"]]
        orig_obj_cls_name_list = Symbol.(split(rel_cls["object_class_name_list"], ","))
        obj_cls_name_list = fix_name_ambiguity(orig_obj_cls_name_list)
        orig_obj_cls_name = Dict(k => v for (k, v) in zip(obj_cls_name_list, orig_obj_cls_name_list))
        obj_cls_name_tuple = Tuple(obj_cls_name_list)
        obj_name_tuples = [NamedTuple{obj_cls_name_tuple}(y) for y in obj_name_lists]
        @suppress_err begin
            @eval begin
                function $(Symbol(rel_cls_name))(;kwargs...)
                    obj_name_tuples = $(obj_name_tuples)
                    obj_cls_name_tuple = $(obj_cls_name_tuple)
                    orig_obj_cls_name = $(orig_obj_cls_name)
                    iter_kwargs = Dict()
                    for (key, val) in kwargs
                        !(key in obj_cls_name_tuple) && error(
                            """invalid keyword '$key' in call to '$($rel_cls_name)': """
                            * """valid keywords are '$(join(obj_cls_name_tuple, "', '"))'"""
                        )
                        obj_cls_name = orig_obj_cls_name[key]
                        applicable(iterate, val) || (val = (val,))
                        vals = []
                        valid_object_names = eval(obj_cls_name)()
                        for v in val
                            if !(v in valid_object_names)
                                @warn(
                                    "invalid object '$v' of class '$key' in call to '$($rel_cls_name)', "
                                    * "will be ignored..."
                                )
                            else
                                push!(vals, v)
                            end
                        end
                        !isempty(vals) && push!(iter_kwargs, key => vals)
                    end
                    result = [x for x in obj_name_tuples if all(x[k] in v for (k, v) in iter_kwargs)]
                    result_keys = Tuple(x for x in obj_cls_name_tuple if !(x in keys(iter_kwargs)))
                    if length(result_keys) == 1
                        unique(x[result_keys...] for x in result)
                    else
                        unique(NamedTuple{result_keys}([x[k] for k in result_keys]) for x in result)
                    end
                end
                export $(Symbol(rel_cls_name))
            end
        end
    end
end


"""
    checkout_spinedb(db_url::String; parse_value=parse_value, upgrade=false)

Generate and export convenience functions for accessing the database
at the given [sqlalchemy url](http://docs.sqlalchemy.org/en/latest/core/engines.html#database-urls).
Three types of functions are generated:

    object_class_name(;kwargs...)

A list of objects in a class.

    relationship_class_name(;kwargs...)

A list of object tuples in a relationship class.

    parameter_name(;kwargs...)

The value of a parameter.

The argument `parse_value` is a function for mapping a tuple `(db_value, tags)` into a Julia value
to be returned by the parameter function. Here, `db_value` is the value retrieved from the database and
parsed using `JSON.parse`, and `tags` is a Union of Tag types.
"""
function checkout_spinedb(db_url::String; parse_value=parse_value, upgrade=false)
    # Create DatabaseMapping object using Python spinedb_api
    try
        db_map = db_api.DatabaseMapping(db_url, upgrade=upgrade)
        checkout_spinedb(db_map; parse_value=parse_value)
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
    checkout_spinedb(db_map::PyObject; parse_value=parse_value)

Generate and export convenience functions for accessing the database
mapped by `db_map`. `db_map` is an instance of `DiffDatabaseMapping` as
provided by [`spinedb_api`](https://github.com/Spine-project/Spine-Database-API).
See [`checkout_spinedb(db_url::String; parse_value=parse_value, upgrade=false)`](@ref)
for more details.

# Example
```julia
julia> checkout_spinedb("sqlite:///examples/data/testsystem2_v2_multiD.sqlite")
julia> commodity()
3-element Array{String,1}:
 "coal"
 "gas"
...
julia> unit_node()
9-element Array{Array{String,1},1}:
String["CoalPlant", "BelgiumCoal"]
String["CoalPlant", "LeuvenElectricity"]
...
julia> conversion_cost(unit="gas_import")
12
julia> demand(node="Leuven", t=17)
700
julia> trans_loss(connection="EL1", node1="LeuvenElectricity", node2="AntwerpElectricity")
0.9
```
"""
function checkout_spinedb(db_map::PyObject; parse_value=parse_value)
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
    class_object_subset_dict = checkout_spinedb_parameter(db_map, object_dict, relationship_dict, parse_value)
    checkout_spinedb_object(db_map, object_dict, class_object_subset_dict)
    checkout_spinedb_relationship(db_map, relationship_dict)
end
