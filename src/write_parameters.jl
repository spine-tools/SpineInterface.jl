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

write_parameter!(::PyObject, ::Symbol, ::Dict{Any,Any}; result::String="") = nothing

"""
    write_parameter!(db_map, name, data; result="")

Add parameter to `db_map` with given `name` and `data`.
Link the parameter to given result object if not empty.
"""
function write_parameter!(
        db_map::PyObject,
        name::Symbol,
        data::Dict{S,T};
        result::String="") where {S<:NamedTuple,T}
    object_classes = []
    !isempty(result) && pushfirst!(object_classes, "result")
    relationship_classes = []
    parameters = []
    for obj_cls_names in unique(keys(key) for key in keys(data))
        str_obj_cls_names = [string(x) for x in obj_cls_names]
        append!(object_classes, str_obj_cls_names)
        !isempty(result) && pushfirst!(str_obj_cls_names, "result")
        rel_cls_name = join(str_obj_cls_names, "__")
        push!(relationship_classes, (rel_cls_name, str_obj_cls_names))
        push!(parameters, (rel_cls_name, string(name)))
    end
    unique!(object_classes)
    objects = []
    !isempty(result) && pushfirst!(objects, ("result", result))
    relationships = []
    parameter_values = []
    for (key, value) in data
        str_obj_cls_names = [string(x) for x in keys(key)]
        str_obj_names = [string(x) for x in values(key)]
        for (obj_cls_name, obj_name) in zip(str_obj_cls_names, str_obj_names)
            push!(objects, (obj_cls_name, obj_name))
        end
        if !isempty(result)
            pushfirst!(str_obj_cls_names, "result")
            pushfirst!(str_obj_names, result)
        end
        rel_cls_name = join(str_obj_cls_names, "__")
        push!(relationships, (rel_cls_name, str_obj_names))
        push!(parameter_values, (rel_cls_name, str_obj_names, string(name), JSON.json(value)))
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
    write_parameters(url::String; upgrade=false, result="", comment="", <parameters>)

Write given `parameters` to the Spine database at the given RFC-1738 `url`.

If `upgrade` is `true`, then the database at `url` is upgraded to the latest revision.

Results...

"""
function write_parameters(dest_url::String; upgrade=false, result="", comment="", parameters...)
    try
        db_map = db_api.DiffDatabaseMapping(dest_url, upgrade=upgrade)
        write_parameters(db_map; result=result, comment=comment, parameters...)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBAPIError)
            db_api.create_new_spine_database(dest_url)
            write_parameters(dest_url; result=result, comment=comment, parameters...)
        else
            rethrow()
        end
    end
end


function write_parameters(db_map::PyObject; result="", comment="", parameters...)
    try
        for (name, data) in parameters
            write_parameter!(db_map, name, data; result=result)
        end
        if isempty(comment)
            comment = string("Add $(join([string(k) for (k, v) in parameters])), automatically from SpineInterface.jl.")
        end
        db_map.commit_session(comment)
    catch err
        db_map.rollback_session()
        rethrow()
    end
end
