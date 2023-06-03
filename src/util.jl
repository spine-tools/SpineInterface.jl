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
        entity, new_kwargs = _split_entity_kwargs(class; kwargs...)
        parameter_values = _entity_pvals(class.parameter_values, entity)
        parameter_values === nothing && continue
        return _get(parameter_values, p.name, class.parameter_defaults, _default), new_kwargs
    end
    if _strict
        error("can't find a value of $p for argument(s) $((; kwargs...))")
    end
end

_dimensionality(x::ObjectClass) = 0
_dimensionality(x::RelationshipClass) = length(x.object_class_names)

function _split_entity_kwargs(class::ObjectClass; kwargs...)
    new_kwargs = OrderedDict(kwargs...)
    pop!(new_kwargs, class.name, missing), (; new_kwargs...)
end
function _split_entity_kwargs(class::RelationshipClass; kwargs...)
    new_kwargs = OrderedDict(kwargs...)
    objects = Tuple(pop!(new_kwargs, oc, missing) for oc in class.object_class_names)
    objects, (; new_kwargs...)
end

_entity_pvals(pvals_by_entity, ::Nothing) = nothing
_entity_pvals(pvals_by_entity, entity) = _entity_pvals(pvals_by_entity, entity, get(pvals_by_entity, entity, nothing))
_entity_pvals(pvals_by_entity, entity, pvals) = pvals
_entity_pvals(pvals_by_entity, ::Missing, ::Nothing) = nothing
_entity_pvals(pvals_by_entity, ::NTuple{N,Missing}, ::Nothing) where {N} = nothing
function _entity_pvals(pvals_by_entity, entity::Tuple, ::Nothing)
    any(x === missing for x in entity) || return nothing
    matched = nothing
    for (key, value) in pvals_by_entity
        if _matches(key, entity)
            matched === nothing || return nothing
            matched = value
        end
    end
    matched
end

_matches(first::Tuple, second::Tuple) = all(_matches(x, y) for (x, y) in zip(first, second))
_matches(x, ::Missing) = true
_matches(x, y) = x == y

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
_do_realize(call::Call, callback=nothing) = _do_realize(call, callback, call.func)
_do_realize(call::Call, callback, ::Nothing) = call.args[1]
function _do_realize(call::Call, callback, pv::T) where {T<:ParameterValue}
    pv(callback; call.kwargs...)
end
function _do_realize(call::Call, callback, ::Function)
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
