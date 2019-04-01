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


function checkout_spinedb_parameter(db_map::PyObject, object_dict::Dict, relationship_dict::Dict)
    parameter_dict = Dict()
    class_object_subset_dict = Dict{Symbol,Any}()
    parameter_list = vcat(
        py"[x._asdict() for x in $db_map.object_parameter_list()]",
        py"[x._asdict() for x in $db_map.relationship_parameter_list()]"
    )
    object_parameter_value_dict =
        py"{(x.parameter_id, x.object_name): x.value for x in $db_map.object_parameter_value_list()}"
    relationship_parameter_value_dict =
        py"{(x.parameter_id, x.object_name_list): x.value for x in $db_map.relationship_parameter_value_list()}"
    value_list_dict = py"{x.id: x.value_list.split(',') for x in $db_map.wide_parameter_value_list_list()}"
    for parameter in parameter_list
        parameter_name = parameter["parameter_name"]
        parameter_id = parameter["id"]
        object_class_name = get(parameter, "object_class_name", nothing)
        relationship_class_name = get(parameter, "relationship_class_name", nothing)
        parsed_default_value = try
            parse_value(parameter["default_value"])
        catch e
            error(
                "unable to parse default value of '$parameter_name': "
                * "$(sprint(showerror, e))"
            )
        end
        tag_list_str = parameter["parameter_tag_list"]
        tag_list = if tag_list_str isa String
            split(tag_list_str, ",")
        else
            []
        end
        value_list_id = parameter["value_list_id"]
        object_subset_dict = if value_list_id != nothing && object_class_name != nothing
            d1 = get!(class_object_subset_dict, Symbol(object_class_name), Dict{Symbol,Any}())
            object_subset_dict = get!(d1, Symbol(parameter_name), Dict{Symbol,Any}())
            value_list = value_list_dict[value_list_id]
            for value in value_list
                object_subset_dict[Symbol(value)] = Array{Symbol,1}()
            end
            object_subset_dict
        else
            nothing
        end
        local class_name
        local entity_name_list
        local symbol_entity_name_fn
        local entity_parameter_value_dict
        if object_class_name != nothing
            class_name = object_class_name
            entity_name_list = object_dict[class_name]
            entity_parameter_value_dict = object_parameter_value_dict
            symbol_entity_name_fn = x -> Symbol(x)
        elseif relationship_class_name != nothing
            class_name = relationship_class_name
            entity_name_list = relationship_dict[class_name]["object_name_lists"]
            entity_parameter_value_dict = relationship_parameter_value_dict
            symbol_entity_name_fn = x -> Tuple(Symbol.(split(x, ",")))
        else
            @warn("'$parameter_name' defined with no class, skipping...")
            continue
        end
        class_parameter_value_dict = get!(parameter_dict, Symbol(parameter_name), Dict{Symbol,Any}())
        parameter_value_dict = class_parameter_value_dict[Symbol(class_name)] = Dict{Union{Symbol,Tuple},Any}()
        # Loop through all parameter values
        for entity_name in entity_name_list
            value = get(entity_parameter_value_dict, (parameter_id, entity_name), nothing)
            symbol_entity_name = symbol_entity_name_fn(entity_name)
            new_value = if value != nothing
                try
                    parse_value(value)
                catch e
                    error(
                        "unable to parse value of '$parameter_name' for '$entity_name': "
                        * "$(sprint(showerror, e))"
                    )
                end
            else
                parsed_default_value
            end
            parameter_value_dict[symbol_entity_name] = new_value
            # Add entry to class_object_subset_dict
            object_subset_dict == nothing && continue
            if haskey(object_subset_dict, Symbol(new_value))
                arr = object_subset_dict[Symbol(new_value)]
                push!(arr, symbol_entity_name)
            else
                @warn string(
                    "found value $new_value for '$symbol_entity_name, $parameter_name', ",
                    "which is not a listed value."
                )
            end
        end
    end
    for (parameter_name, class_parameter_value_dict) in parameter_dict
        @suppress_err begin
            # Create and export convenience functions
            @eval begin
                """
                    $($parameter_name)(;class=entity, t::Union{Int64,String,Nothing}=nothing)

                The value of the parameter '$($parameter_name)' for `entity`
                (and object name in case of an object parameter, a tuple of related object names in case of
                a relationship parameter).
                The argument `t` can be used, e.g., to retrieve a specific position in the returning array.
                """
                function $(parameter_name)(;t::Union{Int64,String,Nothing}=nothing, kwargs...)
                    class_parameter_value_dict = $(class_parameter_value_dict)
                    if length(kwargs) == 0
                        # Return dict if kwargs is empty
                        class_parameter_value_dict
                    elseif length(kwargs) == 1
                        class_name, entity_name = iterate(kwargs)[1]
                        haskey(class_parameter_value_dict, class_name) || error(
                            "'$($parameter_name)' not defined for class '$class_name'"
                        )
                        parameter_value_dict = class_parameter_value_dict[class_name]
                        haskey(parameter_value_dict, entity_name) || error(
                            "'$($parameter_name)' not specified for '$entity_name' of class '$class_name'"
                        )
                        value = parameter_value_dict[entity_name]
                        result = try
                            SpineInterface.get_scalar(value, t)
                        catch e
                            error(
                                "can't get value of '$($parameter_name)' " *
                                "for '$entity_name': $(sprint(showerror, e))"
                            )
                        end
                        return result
                    else # length of kwargs is > 1
                        error(
                            "too many arguments in call to `$($parameter_name)`: "
                            * "expected 2, got $(1 + length(kwargs))"
                        )
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
    for (relationship_class_name, relationship_class_dict) in relationship_dict
        object_name_lists = relationship_class_dict["object_name_lists"]
        orig_object_class_name_list = relationship_class_dict["object_class_name_list"]
        symbol_orig_object_class_name_list = [Symbol(x) for x in split(orig_object_class_name_list, ",")]
        symbol_object_class_name_list = fix_name_ambiguity(symbol_orig_object_class_name_list)
        symbol_object_name_lists = [Symbol.(split(y, ",")) for y in object_name_lists]
        @suppress_err begin
            @eval begin
                function $(Symbol(relationship_class_name))(;kwargs...)
                    symbol_object_name_lists = $(symbol_object_name_lists)
                    symbol_object_class_name_list = $(symbol_object_class_name_list)
                    symbol_orig_object_class_name_list = $(symbol_orig_object_class_name_list)
                    indexes = Array{Int64, 1}()
                    object_name_list = Array{Symbol, 1}()
                    for (object_class_name, object_name) in kwargs
                        index = findfirst(x -> x == object_class_name, symbol_object_class_name_list)
                        index == nothing && error(
                            """invalid keyword '$object_class_name' in call to '$($relationship_class_name)': """
                            * """valid keywords are '$(join(symbol_object_class_name_list, "', '"))'"""
                        )
                        orig_object_class_name = symbol_orig_object_class_name_list[index]
                        object_names = eval(orig_object_class_name)()
                        !(object_name in object_names) && error(
                            "unable to retrieve '$($relationship_class_name)' tuples for '$object_name': "
                            * "not a valid object of class '$orig_object_class_name'"
                        )
                        push!(indexes, index)
                        push!(object_name_list, object_name)
                    end
                    slice = filter(i -> !(i in indexes), collect(1:length(symbol_object_class_name_list)))
                    result = filter(x -> x[indexes] == object_name_list, symbol_object_name_lists)
                    if length(slice) == 1
                        [x[slice][1] for x in result]
                    else
                        [Tuple(x[slice]) for x in result]
                    end
                end
                export $(Symbol(relationship_class_name))
            end
        end
    end
end


"""
    checkout_spinedb(db_url::String)

Generate and export convenience functions
for each object class, relationship class, and parameter, in the database
given by `db_url`. `db_url` is a database url composed according to
[sqlalchemy rules](http://docs.sqlalchemy.org/en/latest/core/engines.html#database-urls).
See [`checkout_spinedb(db_map::PyObject)`](@ref) for more details.
"""
function checkout_spinedb(db_url::String; upgrade=false)
    # Create DatabaseMapping object using Python spinedb_api
    try
        db_map = db_api.DatabaseMapping(db_url, upgrade=upgrade)
        checkout_spinedb(db_map)
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
    checkout_spinedb(db_map::PyObject)

Generate and export convenience functions
for each object class, relationship class, and parameter, in the
database given by `db_map` (see usage below). `db_map` is an instance of `DiffDatabaseMapping`
provided by [`spinedb_api`](https://github.com/Spine-project/Spine-Database-API).

Usage:

  - **object class**: call `object_class()` to get the set of objects of class `object_class`.
  - **relationship class**: call `relationship_class()` to get the set of object-tuples related
    under `relationship_class`;
    alternatively, call `relationship_class(object_class=:object)` to get the
    set of object-tuples related to `object`.
  - **parameter**: call `parameter(object_class=:object)` to get the value of
    `parameter` for `object`, which is of class `object_class`.
    If value is an `Array`, then call `parameter(object_class=:object, t=t)` to get
    position `t`.

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
function checkout_spinedb(db_map::PyObject)
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
    class_object_subset_dict = checkout_spinedb_parameter(db_map, object_dict, relationship_dict)
    checkout_spinedb_object(db_map, object_dict, class_object_subset_dict)
    checkout_spinedb_relationship(db_map, relationship_dict)
end
