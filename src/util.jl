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
    class_ent_kwargs_iter = (
        (class, _split_entity_kwargs(class; kwargs...))
        for class in sort(p.classes; by=class -> _dimensionality(class), rev=true)
    )
    for find_best_match in (false, true)
        for (class, (entity, new_kwargs)) in class_ent_kwargs_iter
            val = _entity_pval(class, entity, p.name; find_best_match=find_best_match)
            val === nothing && continue
            if val === missing
                val = _default === nothing ? class.default_parameter_values[p.name] : parameter_value(_default)
            end
            return val, new_kwargs
        end
    end
    if _strict
        error("can't find a value of $p for argument(s) $((; kwargs...))")
    end
end

_dimensionality(x::ObjectClass) = 0
_dimensionality(x::RelationshipClass) = length(x.intact_object_class_names)

function _split_entity_kwargs(class; kwargs...)
    kwargs = OrderedDict(kwargs...)
    entity = _extract_entity!(class, kwargs)
    entity, kwargs
end

function _extract_entity!(class::ObjectClass, kwargs)
    pop!(kwargs, class.name, anything)
end
function _extract_entity!(class::RelationshipClass, kwargs)
    Tuple(pop!(kwargs, n, anything) for n in _object_class_names(class))
end

_object_class_names(oc::ObjectClass) = [oc.name]
_object_class_names(rc::RelationshipClass) = propertynames(rc.entities)[1:_dimensionality(rc)]

function _entity_pval(class, entity, p_name; find_best_match=false)
    rows = get(class.rows_by_entity, entity, [])
    length(rows) == 1 && return class.entities[rows[1], p_name]
    find_best_match || return nothing
    rows = _find_rows(class, entity)
    (rows == (:) || length(rows) != 1) && return nothing
    class.entities[rows[1], p_name]
end

function _find_rows(class::ObjectClass, entity)
    get(class.rows_by_entity, entity, [])
end
function _find_rows(class::RelationshipClass, entity)
    rows = get(class.rows_by_entity, entity, [])
    isempty(rows) || return rows
    _find_rows_intersection(class, entity)
end

function _find_rows_intersection(class, entity)
    rows_per_dim = [_rows(class, dim_name, el) for (dim_name, el) in zip(_object_class_names(class), entity)]
    filter!(!=(anything), rows_per_dim)
    isempty(rows_per_dim) && return (:)
    length(rows_per_dim) == 1 && return rows_per_dim[1]
    _intersect_sorted(rows_per_dim...)
end
function _rows(class, dim_name, object::ObjectLike)
    get(class.rows_by_element, (; dim_name => object), [])
end
function _rows(_class, _dim_name, ::Anything)
    anything
end
function _rows(class, dim_name, objects)
    rows = [r for obj in objects for r in _rows(class, dim_name, obj)]
    # TODO: the rows for each object are sorted, so maybe we can sort the union faster??
    sort!(rows)
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
    isempty(entity_df) && return
    _add_object_class_rows!(obj_cls.rows_by_entity, entity_df[!, obj_cls.name], nrow(obj_cls.entities))
    append!(obj_cls.entities, entity_df; cols=:subset)
end

function _add_entities!(rel_cls::RelationshipClass, entity_df)
    isempty(entity_df) && return
    _add_relationship_class_rows!(
        rel_cls.rows_by_entity,
        rel_cls.rows_by_element,
        entity_df[!, _object_class_names(rel_cls)],
        nrow(rel_cls.entities)
    )
    append!(rel_cls.entities, entity_df; cols=:subset)
end

function _add_object_class_rows!(rows_by_entity, entity_vector, offset=0)
    for (k, obj) in enumerate(entity_vector)
        rows_by_entity[obj] = [offset + k]
    end
end

function _add_relationship_class_rows!(rows_by_entity, rows_by_element, entity_df, offset=0)
    for (k, row) in enumerate(eachrow(entity_df))
        ent = Tuple(row)
        rows_by_entity[ent] = [offset + k]
        for (dim_name, el) in zip(keys(row), values(row))
            push!(get!(rows_by_element, (; dim_name => el), []), offset + k)
        end
    end
end




