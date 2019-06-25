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

add_var_to_result!(::PyObject, ::Symbol, ::Dict{Any,Any}, ::Dict{Any,Any}, ::Dict{Any,Any}) = nothing

"""
    add_var_to_result!(db_map, var_name, var, result_class, result_object)

Update `db_map` with data for parameter `var_name` given in `var`.
Link the parameter to a `result_object` of class `result_class`.
"""
function add_var_to_result!(
        db_map::PyObject,
        var_name::Symbol,
        var::Dict{S,T},
        result_class::Dict,
        result_object::Dict) where {S<:NamedTuple,T}
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
    try
        db_map = db_api.DiffDatabaseMapping(dest_url, upgrade=upgrade)
        write_results(db_map; results...)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBAPIError)
            db_api.create_new_spine_database(dest_url)
            write_results(dest_url; results...)
        else
            rethrow()
        end
    end
end


function write_results(db_map::PyObject; result="", results...)
    try
        result_class = py"$db_map.add_object_classes(dict(name='result'), return_dups=True)[0].one()._asdict()"
        timestamp = Dates.format(Dates.now(), "yyyymmdd_HH_MM_SS")
        if isempty(result)
            result = join(["result", timestamp], "_")
        end
        object_ = Dict(
            "name" => result,
            "class_id" => result_class["id"]
        )
        result_object = py"$db_map.add_objects($object_, return_dups=True)[0].one()._asdict()"
        # Insert variable into spine database.
        for (name, var) in results
            add_var_to_result!(db_map, name, var, result_class, result_object)
        end
        msg = string("Add $(join([string(k) for (k, v) in results])), automatically from SpineInterface.jl.")
        db_map.commit_session(msg)
    catch err
        db_map.rollback_session()
        rethrow()
    end
end
