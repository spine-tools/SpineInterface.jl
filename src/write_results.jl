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
    pack_var_dict(var::Dict, n::Int64=1)

"""
# TODO: handle n > 1 nicely
function pack_var_dict(var::Dict, n::Int64=1)
    left_var = Dict{Any,Any}()
    for (key, value) in var
        left_key = key[1:end-n]
        right_key = key[end-n+1:end]
        right_dict = get!(left_var, left_key, Dict())
        right_dict[right_key] = value
    end
    Dict(key => [v for (k, v) in sort(collect(value))] for (key, value) in left_var)
end

"""
    add_var_to_result!(db_map::PyObject, var_name::Symbol, dataframe::DataFrame, result_class::Dict, result_object::Dict)

Update `db_map` with data for parameter `var_name` given in `dataframe`.
Link the parameter to a `result_object` of class `result_class`.
"""
function add_var_to_result!(
        db_map::PyObject,
        var_name::Symbol,
        var::Dict,
        result_class::Dict,
        result_object::Dict
    )
    packed_var = pack_var_dict(var)
    object_class_name_list = PyVector(py"""[$result_class['name']]""")
    object_class_id_list = PyVector(py"""[$result_class['id']]""")
    # Iterate over first keys in the packed variable to retrieve object classes
    for object_name in first(keys(packed_var))
        py"""object_ = $db_map.single_object(name=$object_name).one_or_none()
        """
        if py"object_" != nothing
            py"""object_class = $db_map.single_object_class(id=object_.class_id).one_or_none()
            """
            if py"object_class" != nothing
                push!(object_class_name_list, py"object_class.name")
                push!(object_class_id_list, py"object_class.id")
                continue
            end
        end
        # Object or class not found, add dummy object class named after the object
        object_class_name = string(object_name, "_class")
        py"""object_class = $db_map.add_object_classes(dict(name=$object_class_name), return_dups=True)[0].one()
        """
        push!(object_class_name_list, object_class_name)
        push!(object_class_id_list, py"object_class.id")
    end
    # Get or add relationship class `result__object_class1__object_class2__...`
    relationship_class_name = join(object_class_name_list, "__")
    wide_relationship_class = Dict(
        "name" => relationship_class_name,
        "object_class_id_list" => object_class_id_list
    )
    py"""relationship_class = $db_map.add_wide_relationship_classes(
        $wide_relationship_class, return_dups=True)[0].one()
    """
    # Get or add parameter named after variable
    parameter = Dict(
        "name" => var_name,
        "relationship_class_id" => py"relationship_class.id"
    )
    py"""parameter = $db_map.add_parameters($parameter, return_dups=True)[0].one()
    """
    # Sweep packed variable to compute dictionaries of relationship and parameter value args
    relationship_kwargs_list = []
    parameter_value_kwargs_list = []
    for (object_name_tuple, json) in packed_var
        object_name_list = PyVector(py"""[$result_object['name']]""")
        object_id_list = PyVector(py"""[$result_object['id']]""")
        for object_name in object_name_tuple
            py"""object_ = $db_map.single_object(name=$object_name).one_or_none()
            """
            if py"object_" == nothing
                @warn "Couldn't find object '$object_name', skipping row..."
                break
            end
            push!(object_name_list, object_name)
            push!(object_id_list, py"object_.id")
        end
        # Add relationship `result_object__object1__object2__...
        relationship_name = join(object_name_list, "__")
        push!(
            relationship_kwargs_list,
            Dict(
                "name" => relationship_name,
                "object_id_list" => object_id_list,
                "class_id" => py"relationship_class.id"
            )
        )
        # Add parameter value
        push!(
            parameter_value_kwargs_list,
            Dict(
                "parameter_id" => py"parameter.id",
                "json" => json
            )
        )
    end
    # Add relationships
    py_relationship_kwargs_list = PyVector(relationship_kwargs_list)
    relationship_list = py"""$db_map.add_wide_relationships(*$py_relationship_kwargs_list, return_dups=True)[0]"""
    # Complete parameter value args with relationship ids
    for (i, relationship) in enumerate(py"""[x._asdict() for x in $relationship_list]""")
        parameter_value_kwargs_list[i]["relationship_id"] = relationship["id"]
    end
    py_parameter_value_kwargs_list = PyVector(parameter_value_kwargs_list)
    py"""$db_map.add_parameter_values(*$py_parameter_value_kwargs_list)"""
end

"""
    write_results!(dest_url::String; results...)

Update `dest_url` with new parameters given by `results`.
`dest_url` is a database url composed according to
[sqlalchemy rules](http://docs.sqlalchemy.org/en/latest/core/engines.html#database-urls).
"""
function write_results!(dest_url::String; upgrade=false, results...)
    db_map = db_api.DiffDatabaseMapping(dest_url, "spine_interface"; upgrade=upgrade)
    try
        result_class = py"""$db_map.add_object_classes(dict(name="result"), return_dups=True)[0].one()._asdict()"""
        timestamp = Dates.format(Dates.now(), "yyyymmdd_HH_MM_SS")
        result_name = join(["result", timestamp], "_")
        object_ = Dict(
            "name" => result_name,
            "class_id" => result_class["id"]
        )
        result_object = py"""$db_map.add_objects($object_, return_dups=True)[0].one()._asdict()"""
        # Insert variable into spine database.
        for (name, var) in results
            # dataframe = packed_var_dataframe(var)
            add_var_to_result!(db_map, name, var, result_class, result_object)
        end
        msg = string("Add ", join([string(k) for (k, v) in results], ", "), ", automatically from SpineInterface.jl.")
        db_map.commit_session(msg)
    catch err
        db_map.rollback_session()
        rethrow()
    finally
        db_map.close()
    end
end

"""
    write_results!(dest_url, source_url; results...)

Update `dest_url` with classes and objects from `source_url`,
as well as new parameters given by `results`.
"""
function write_results!(dest_url, source_url; upgrade=false, results...)
    if db_api.is_unlocked(dest_url)
        create_results_database(dest_url, source_url; upgrade=upgrade)
        write_results!(dest_url; results...)
    else
        @warn string(
"""
The current operation cannot proceed because the SQLite database '$dest_url' is locked.
The operation will resume automatically if the lock is released within the next 2 minutes.
"""
        )
        if db_api.is_unlocked(dest_url, timeout=120)
            create_results_database(dest_url, source_url)
            write_results!(dest_url; upgrade=upgrade, results...)
        else
            timestamp = Dates.format(Dates.now(), "yyyymmdd_HH_MM_SS")
            alt_dest_url = "sqlite:///result_$timestamp.sqlite"
            info("The database $dest_url is locked. Saving results to $alt_dest_url instead.")
            create_results_database(alt_dest_url, source_url; upgrade=upgrade)
            write_results!(alt_dest_url; results...)
        end
    end
end


function create_results_database(dest_url, source_url)
    try
        db_api.copy_database(
            dest_url, source_url; overwrite=false, skip_tables=["parameter", "parameter_value"])
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBVersionError)
            error(
"""
The database at '$(e.val.url)' is from an older version of Spine
and needs to be upgraded in order to be used with the current version.

You can upgrade by passing the keyword argument `upgrade=true` to your function call, e.g.:

    write_results!(dest_url, source_url; upgrade=true, results...)

WARNING: After the upgrade, the database may no longer be used
with previous versions of Spine.
"""
            )
        else
            rethrow()
        end
    end

end
