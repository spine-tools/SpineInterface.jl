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
    write_parameter!(db_map, name, data; for_object=true, report="")

Write parameter to `db_map` with given `name` and `data`.
Link the parameter to given `report` object.
"""
function write_parameter!(
        db_map::PyObject,
        name,
        data::Dict{K,V};
        for_object::Bool=true,
        report::String="") where {K<:NamedTuple,V}
    object_classes = []
    object_parameters = []
    objects = []
    object_parameter_values = []
    relationship_classes = []
    relationship_parameters = []
    relationships = []
    relationship_parameter_values = []
    !isempty(report) && pushfirst!(object_classes, "report")
    for obj_cls_names in unique(keys(key) for key in keys(data))
        str_obj_cls_names = [string(x) for x in obj_cls_names]
        append!(object_classes, str_obj_cls_names)
        !isempty(report) && pushfirst!(str_obj_cls_names, "report")
        if for_object && length(str_obj_cls_names) == 1
            obj_cls_name = str_obj_cls_names[1]
            push!(object_parameters, (obj_cls_name, string(name)))
        else
            rel_cls_name = join(str_obj_cls_names, "__")
            push!(relationship_classes, (rel_cls_name, str_obj_cls_names))
            push!(relationship_parameters, (rel_cls_name, string(name)))
        end
    end
    unique!(object_classes)
    !isempty(report) && pushfirst!(objects, ("report", report))
    for (key, value) in data
        str_obj_cls_names = [string(x) for x in keys(key)]
        str_obj_names = [string(x) for x in values(key)]
        for (obj_cls_name, obj_name) in zip(str_obj_cls_names, str_obj_names)
            push!(objects, (obj_cls_name, obj_name))
        end
        if !isempty(report)
            pushfirst!(str_obj_cls_names, "report")
            pushfirst!(str_obj_names, report)
        end
        if for_object && length(str_obj_cls_names) == length(str_obj_names) == 1
            obj_cls_name = str_obj_cls_names[1]
            obj_name = str_obj_names[1]
            push!(object_parameter_values, (obj_cls_name, obj_name, string(name), value))
        else
            rel_cls_name = join(str_obj_cls_names, "__")
            push!(relationships, (rel_cls_name, str_obj_names))
            push!(relationship_parameter_values, (rel_cls_name, str_obj_names, string(name), value))
        end
    end
    added, err_log = db_api.import_data(
        db_map,
        object_classes=object_classes,
        relationship_classes=relationship_classes,
        object_parameters=object_parameters,
        relationship_parameters=relationship_parameters,
        objects=objects,
        relationships=relationships,
        object_parameter_values=object_parameter_values,
        relationship_parameter_values=relationship_parameter_values,
    )
    isempty(err_log) || @warn join([x.msg for x in err_log], "\n")
    added
end


"""
    write_parameters(parameters, url::String; <keyword arguments>)

Write `parameters` to the Spine database at the given RFC-1738 `url`.
`parameters` is a dictionary mapping parameter names to another dictionary 
mapping object or relationship (`NamedTuple`) to values.

# Arguments

- `upgrade::Bool=true`: whether or not the database at `url` should be upgraded to the latest revision.
- `for_object::Bool=true`: whether to write an object parameter or a 1D relationship parameter in case the number of 
    dimensions is 1.
- `report::String=""`: the name of a report object that will be added as an extra dimension to the written parameters.
- `comment::String=""`: a comment explaining the nature of the writing operation.
- `<parameters>`: a dictionary mapping
"""
function write_parameters(
        parameters::Dict{T,Dict{K,V}}, dest_url::String; upgrade=false, for_object=true, report="", comment=""
    ) where {T,K<:NamedTuple,V}
    db_map = try
        db_api.DiffDatabaseMapping(dest_url, upgrade=upgrade)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBAPIError)
            db_api.create_new_spine_database(dest_url; for_spine_model=true)
            db_api.DiffDatabaseMapping(dest_url, upgrade=upgrade)
        else
            rethrow()
        end
    end
    write_parameters(parameters, db_map; for_object=for_object, report=report, comment=comment)
end


function write_parameters(
        parameters::Dict{T,Dict{K,V}}, db_map::PyObject; for_object=true, report="", comment=""
    ) where {T,K<:NamedTuple,V}
    added = 0
    for (name, data) in parameters
        added += write_parameter!(db_map, name, data; report=report)
    end
    added == 0 && return
    if isempty(comment)
        comment = string("Add $(join([string(k) for (k, v) in parameters])), automatically from SpineInterface.jl.")
    end
    try
        db_map.commit_session(comment)
    catch err
        db_map.rollback_session()
        rethrow()
    end
end
