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

# Constants, and utility functions that are used in more than one file.
# (Everything that is used in only one file, we put it in the same file.)

const _df = DateFormat("yyyy-mm-ddTHH:MM")
const _db_df = dateformat"yyyy-mm-ddTHH:MM:SS.s"
const _alt_db_df = dateformat"yyyy-mm-dd HH:MM:SS.s"
const _required_spinedb_api_version = v"0.23.2"
const _client_version = 6
const _EOT = '\u04'  # End of transmission
const _START_OF_TAIL = '\u1f'  # Unit separator
const _START_OF_ADDRESS = '\u91'  # Private Use 1
const _ADDRESS_SEP = ':'

const _spinedb_api_not_found(pyprogramname) = """
The required Python package `spinedb_api` could not be found in the current Python environment
    $pyprogramname

You can fix this in two different ways:

    A. Install `spinedb_api` in the current Python environment; open a terminal (command prompt on Windows) and run

        $pyprogramname -m pip install --user 'git+https://github.com/Spine-project/Spine-Database-API'

    B. Switch to another Python environment that has `spinedb_api` installed; from Julia, run

        ENV["PYTHON"] = "... path of the python executable ..."
        Pkg.build("PyCall")

    And restart Julia.
"""

const _required_spinedb_api_version_not_found_py_call(pyprogramname) = """
The required version $_required_spinedb_api_version of `spinedb_api` could not be found in the current Python environment

    $pyprogramname

You can fix this in two different ways:

    A. Upgrade `spinedb_api` to its latest version in the current Python environment; open a terminal (command prompt on Windows) and run

        $pyprogramname -m pip upgrade --user 'git+https://github.com/Spine-project/Spine-Database-API'

    B. Switch to another Python environment that has `spinedb_api` version $_required_spinedb_api_version installed; from Julia, run

        ENV["PYTHON"] = "... path of the python executable ..."
        Pkg.build("PyCall")

    And restart Julia.
"""

const _required_spinedb_api_version_not_found_server = """
The required version $_required_spinedb_api_version of `spinedb_api` could not be found.
Please update Spine Toolbox by following the instructions at

    https://github.com/Spine-project/Spine-Toolbox#installation
"""

function _getproperty(m::Module, name::Symbol, default)
    isdefined(m, name) ? getproperty(m, name) : default
end

function _getproperty!(m::Module, name::Symbol, default)
    if !isdefined(m, name)
        @eval m $name = $default
    end
    getproperty(m, name)
end

function _get(d, key, backup, default=nothing)
    get(d, key) do
        default !== nothing ? parameter_value(default) : backup[key]
    end
end

function _split_parameter_value_kwargs(p::Parameter; _strict=true, _default=nothing, kwargs...)
    _strict &= _default === nothing
    for class in sort(p.classes; by=class -> _dimensionality(class), rev=true)
        entity_kwargs, other_kwargs = _split_entity_kwargs(class; kwargs...)
        val = _entity_pval(class, entity_kwargs, p.name)
        val === nothing && continue
        if val === missing
            val = _default === nothing ? class.default_parameter_values[p.name] : parameter_value(_default)
        end
        return val, other_kwargs
    end
    if _strict
        error("can't find a value of $p for argument(s) $((; kwargs...))")
    end
end

_dimensionality(x::ObjectClass) = 0
_dimensionality(x::RelationshipClass) = length(x.intact_object_class_names)

function _split_entity_kwargs(class::ObjectClass; kwargs...)
    kwargs = OrderedDict(kwargs...)
    Dict(class.name => pop!(kwargs, class.name, anything)), (; kwargs...)
end
function _split_entity_kwargs(class::RelationshipClass; kwargs...)
    kwargs = OrderedDict(kwargs...)
    entity_kwargs = Dict(oc_name => pop!(kwargs, oc_name, anything) for oc_name in _object_class_names(class))
    entity_kwargs, (; kwargs...)
end

_object_class_names(oc::ObjectClass) = [oc.name]
_object_class_names(rc::RelationshipClass) = propertynames(rc.entities)[1:_dimensionality(rc)]

function _entity_pval(class, entity_kwargs, p_name)
    rows = _find_rows(class, entity_kwargs)
    sdf = @view class.entities[rows, :]
    nrow(sdf) != 1 && return nothing
    sdf[1, p_name]
end

function _find_rows(class, kwargs)
    rows_per_dim = [_rows(class, dim_name, object) for (dim_name, object) in kwargs]
    filter!(!=(anything), rows_per_dim)
    isempty(rows_per_dim) && return (:)
    length(rows_per_dim) == 1 && return rows_per_dim[1]
    _intersect_sorted(rows_per_dim...)
end

function _rows(class::ObjectClass, _dim_name, object::Object)
    get(class.row_map, object, [])
end
function _rows(class::RelationshipClass, dim_name, object::Object)
    get(class.row_map, (dim_name, object), [])
end
function _rows(_class, _dim_name, ::Anything)
    anything
end
function _rows(class, dim_name, objects)
    rows = [_rows(class, dim_name, obj) for obj in objects]
    sort!(rows; by=first)
    vcat(rows...)
end

function _intersect_sorted(rows...)
    result = []
    inds = collect(firstindex.(rows))
    @inbounds while all(inds .<= lastindex.(rows))
        vals = [row[i] for (i, row) in zip(inds, rows)]
        max_val = maximum(vals)
        behind = vals .< max_val
        if any(behind)
            inds .+= behind
        else
            push!(result, max_val)
            inds .+= 1
        end
    end
    result
end

function _entity_filter(kwargs)
    row -> all(row[class_name] in objects for (class_name, objects) in kwargs)
end

struct _CallNode
    call::Call
    parent::Union{_CallNode,Nothing}
    child_number::Int64
    children::Vector{_CallNode}
    value::Ref{Any}
    function _CallNode(call, parent, child_number)
        node = new(call, parent, child_number, Vector{_CallNode}(), Ref(nothing))
        if parent !== nothing
            push!(parent.children, node)
        end
        node
    end
end

_do_realize(x, callback=nothing) = x
_do_realize(call::Call, callback=nothing) = _do_realize(call.func, call, callback)
_do_realize(::Nothing, call, callback) = call.args[1]
_do_realize(pv::T, call, callback) where T<:ParameterValue = pv(callback; call.kwargs...)
function _do_realize(::T, call::Call, callback) where T<:Function
    current = _CallNode(call, nothing, -1)
    while true
        vals = [child.value[] for child in current.children]
        if !isempty(vals)
            # children already visited, compute value
            current.value[] = length(vals) == 1 ? current.call.func(vals[1]) : reduce(current.call.func, vals)
        elseif current.call.func isa Function
            # visit children
            current = _first_child(current)
            continue
        else
            # no children, realize value
            current.value[] = _do_realize(current.call, callback)
        end
        current.parent === nothing && break
        if current.child_number < length(current.parent.call.args)
            # visit sibling
            current = _next_sibling(current)
        else
            # go back to parent
            current = current.parent
        end
    end
    current.value[]
end

_first_child(node::_CallNode) = _CallNode(node.call.args[1], node, 1)

function _next_sibling(node::_CallNode)
    sibling_child_number = node.child_number + 1
    _CallNode(node.parent.call.args[sibling_child_number], node.parent, sibling_child_number)
end

_parameter_value_metadata(value) = Dict()
function _parameter_value_metadata(value::TimePattern)
    prec_by_key = Dict(:Y => Year, :M => Month, :D => Day, :WD => Day, :h => Hour, :m => Minute, :s => Second)
    precisions = unique(
        prec_by_key[interval.key] for union in keys(value) for intersection in union for interval in intersection
    )
    sort!(precisions; by=x -> Dates.toms(x(1)))
    Dict(:precision => first(precisions))
end
function _parameter_value_metadata(value::TimeSeries)
    if value.repeat
        Dict(
            :span => value.indexes[end] - value.indexes[1],
            :valsum => sum(Iterators.filter(!isnan, value.values)),
            :len => count(!isnan, value.values),
        )
    else
        Dict()
    end
end

"""
Append an increasing integer to each repeated element in `name_list`, and return the modified `name_list`.
"""
function _fix_name_ambiguity(intact_name_list)
    name_list = copy(intact_name_list)
    for ambiguous in Iterators.filter(name -> count(name_list .== name) > 1, unique(name_list))
        for (k, index) in enumerate(findall(name_list .== ambiguous))
            name_list[index] = Symbol(name_list[index], k)
        end
    end
    name_list
end

function _add_entities!(obj_cls::ObjectClass, entity_df)
    offset = nrow(obj_cls.entities)
    for (row, obj) in enumerate(entity_df[!, obj_cls.name])
        obj_cls.row_map[obj] = [offset + row]
    end
    append!(obj_cls.entities, entity_df; cols=:subset)
end

function _add_entities!(rel_cls::RelationshipClass, entity_df)
    offset = nrow(rel_cls.entities)
    for dim_name in _object_class_names(rel_cls)
        for (row, obj) in enumerate(entity_df[!, dim_name])
            push!(get!(rel_cls.row_map, (dim_name, obj), []), offset + row)
        end
    end
    append!(rel_cls.entities, entity_df; cols=:subset)
end