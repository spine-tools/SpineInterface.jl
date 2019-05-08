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
    add_var_to_result!(db_map, var_name, var, object_class_dict, object_dict, result_class, result_object)

Update `db_map` with data for parameter `var_name` given in `var`.
Link the parameter to a `result_object` of class `result_class`.
"""
# NOTE: this will be deprecated in favor of the method just below where var is a Dict{NamedTuple,T}
function add_var_to_result!(
        db_map::PyObject,
        var_name::Symbol,
        var::Dict,
        object_class_dict::Dict,
        object_dict::Dict,
        result_class::Dict,
        result_object::Dict
    )
    object_class_name_list = PyVector(py"""[$result_class['name']]""")
    object_class_id_list = PyVector(py"""[$result_class['id']]""")
    # Iterate over first keys in the packed variable to retrieve object classes
    object_names = tuple(first(keys(var))...)  # This makes it a tuple if it wasn't
    for object_name in object_names
        string_object_name = string(object_name)
        haskey(object_class_dict, string_object_name) || error(
            "Couldn't find object '$string_object_name'"
        )
        object_class_id, object_class_name = object_class_dict[string_object_name]
        push!(object_class_name_list, object_class_name)
        push!(object_class_id_list, object_class_id)
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
    for (object_name_tuple, value) in var
        object_name_list = PyVector(py"""[$result_object['name']]""")
        object_id_list = PyVector(py"""[$result_object['id']]""")
        object_name_tuple = tuple(object_name_tuple...)  # This makes it a tuple if it wasn't
        for (k, object_name) in enumerate(object_name_tuple)
            object_class_id = object_class_id_list[k+1]
            id_dict = object_dict[object_class_id]
            string_object_name = string(object_name)
            if haskey(id_dict, string_object_name)
                object_id = id_dict[string_object_name]
            else
                @warn "Couldn't find object '$string_object_name', skipping row..."
                break
            end
            push!(object_name_list, string_object_name)
            push!(object_id_list, object_id)
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
                "value" => JSON.json(value)
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


function add_var_to_result!(
        db_map::PyObject,
        var_name::Symbol,
        var::Dict{NamedTuple{R,S},T},
        ::Dict,
        ::Dict,
        result_class::Dict,
        result_object::Dict) where R where S where T
    object_classes = []
    relationship_classes = []
    parameters = []
    for obj_cls_names in unique(keys(key) for key in keys(var))
        str_obj_cls_names = [string(x) for x in obj_cls_names]
        append!(object_classes, str_obj_cls_names)
        pushfirst!(str_obj_cls_names, result_class["name"])
        rel_cls_name = join(str_obj_cls_names, "__")
        push!(relationship_classes, (rel_cls_name, str_obj_cls_names))
        push!(parameters, (rel_cls_name, string(var_name)))
    end
    unique!(object_classes)
    objects = []
    relationships = []
    parameter_values = []
    for (key, value) in var
        str_obj_cls_names = [string(x) for x in keys(key)]
        str_obj_names = [string(x) for x in values(key)]
        for (obj_cls_name, obj_name) in zip(str_obj_cls_names, str_obj_names)
            push!(objects, (obj_cls_name, obj_name))
        end
        pushfirst!(str_obj_cls_names, result_class["name"])
        rel_cls_name = join(str_obj_cls_names, "__")
        pushfirst!(str_obj_names, result_object["name"])
        push!(relationships, (rel_cls_name, str_obj_names))
        push!(parameter_values, (rel_cls_name, str_obj_names, string(var_name), JSON.json(value)))
    end
    added, err_log = db_api.import_data(
        db_map,
        object_classes=object_classes,
        relationship_classes=relationship_classes,
        relationship_parameters=parameters,
        objects=objects,
        relationships=relationships,
        relationship_parameter_values=parameter_values,
    )
    isempty(err_log) || @warn join([x.msg for x in err_log], "\n")
end


"""
    write_results(dest_url::String; upgrade=false, results...)

Update `dest_url` with new parameters given by `results`.
`dest_url` is a database url composed according to
[sqlalchemy rules](http://docs.sqlalchemy.org/en/latest/core/engines.html#database-urls).
"""
function write_results(dest_url::String; upgrade=false, results...)
    # TODO: Try to catch a nice error here so as to create an empty SpineModel db
    try
        db_map = DiffDatabaseMapping(dest_url)
        write_results(db_map; upgrade=upgrade, results...)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBAPIError)
            db_api.create_new_spine_database(dest_url)
            write_results(dest_url; results...)
        else
            rethrow()
        end
    end
end


function write_results(db_map::PyObject; upgrade=false, results...)
    try
        py"""object_list = $db_map.object_list().all()
        object_class_list = $db_map.object_class_list().all()
        d = {x.id: (x.id, x.name) for x in object_class_list}
        object_class_dict = {x.name: d[x.class_id] for x in $db_map.object_list()}
        object_dict = {
            x.id: {y.name: y.id for y in object_list if y.class_id == x.id} for x in object_class_list
        }
        """
        object_class_dict = py"object_class_dict"
        object_dict = py"object_dict"
        result_class = py"$db_map.add_object_classes(dict(name='result'), return_dups=True)[0].one()._asdict()"
        timestamp = Dates.format(Dates.now(), "yyyymmdd_HH_MM_SS")
        result_object_name = join(["result", timestamp], "_")
        object_ = Dict(
            "name" => result_object_name,
            "class_id" => result_class["id"]
        )
        result_object = py"$db_map.add_objects($object_, return_dups=True)[0].one()._asdict()"
        # Insert variable into spine database.
        for (name, var) in results
            add_var_to_result!(db_map, name, var, object_class_dict, object_dict, result_class, result_object)
        end
        msg = string("Add $(join([string(k) for (k, v) in results])), automatically from SpineInterface.jl.")
        db_map.commit_session(msg)
    catch err
        db_map.rollback_session()
        rethrow()
    end
end
