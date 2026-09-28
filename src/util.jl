#############################################################################
# Copyright (C) 2017 - 2021 Spine project consortium
# Copyright SpineInterface contributors
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

# Utility functions that are used in more than one file.
# (Everything that is used in only one file, we put it in the same file.)

function _get(d, key, backup, default=nothing)
    get(d, key) do
        default !== nothing ? parameter_value(default) : backup[key]
    end
end

_do_realize(x, _upd) = x
_do_realize(call::Call, upd) = _do_realize(call.func, call, upd)
_do_realize(::Nothing, call, _upd) = realize(call.args[1])
function _do_realize(pv::T, call, upd) where T<:ParameterValue
    pv(call.kwargs, upd)
end
function _do_realize(::T, call, upd) where T<:Function
    if call.root_node[] === nothing
        call.root_node[] = _root_node(call)
    end
    node = call.root_node[]
    direction = :down
    while true
        if direction != :up
            if isempty(node.children)
                node.value[] = realize(node.call, upd)
            end
        else
            node.value[] = node.call.func((child.value[] for child in node.children)...)
        end
        node_and_direction = _next_node_and_direction(node, direction)
        node_and_direction === nothing && break
        node, direction = node_and_direction
    end
    call.root_node[].value[]
end

function _visit_call!(func, call)
    if call.root_node[] === nothing
        call.root_node[] = _root_node(call)
    end
    node = call.root_node[]
    direction = :down
    while true
        func(node, direction)
        node_and_direction = _next_node_and_direction(node, direction)
        node_and_direction === nothing && break
        node, direction = node_and_direction
    end
end

function _next_node_and_direction(current, direction)
    if direction != :up && !isempty(current.children)
        # visit child
        first(current.children), :down
    elseif current.parent !== nothing
        if current.child_number < length(current.parent.children)
            # visit sibling
            current.parent.children[current.child_number + 1], :side
        else
            # go back to parent
            current.parent, :up
        end
    end
end

function _root_node(call)
    current = _CallNode(call, nothing, -1)
    while true
        if isempty(current.children) && current.call isa Call && current.call.func isa Function
            current = _first_child(current)
            continue
        end
        current.parent === nothing && break
        sibling = _next_sibling(current)
        if sibling !== nothing
            current = sibling
        else
            current = current.parent
        end
    end
    current
end

_first_child(node::_CallNode) = _CallNode(node.call.args[1], node, 1)

function _next_sibling(node::_CallNode)
    sibling_child_number = node.child_number + 1
    sibling_child_number > length(node.parent.call.args) && return nothing
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

function _refresh_metadata!(pval::ParameterValue)
    empty!(pval.metadata)
    merge!(pval.metadata, _parameter_value_metadata(pval.value))
end

function _add_update!(t::TimeSlice, timeout, upd)
    t.updates[upd] = timeout
end

"""
    _find_permutation(a::Vector, b::Vector)

Return which permutation of `b` `a` is.
"""
_find_permutation(a::Vector, b::Vector) = [findfirst(x .== b) for x in a]::Vector{<:Integer}

"""
    uniquefy_elements(elements::Vector{Symbol})

Return a list of unique `Symbol`s based on `elements` differentiated by an increasing index.
"""
function uniquefy_elements(elements::Vector{Symbol})
    uniques = Vector{Symbol}(undef, length(elements))
    return _uniquefy!(uniques, elements)
end
function uniquefy_elements(elements::NTuple{N,Symbol} where N)
    return Tuple(uniquefy_elements(collect(elements)))
end

function _uniquefy!(uniques::Vector, elements)
    for (element_i, element) in enumerate(elements)
        preceding_count = count(e -> e == element, elements[1:element_i - 1])
        if preceding_count == 0 && count(e -> e == element, elements[element_i + 1: end]) == 0
            uniques[element_i] = element
        else
            uniques[element_i] = Symbol(element, preceding_count + 1)
        end
    end
    return uniques::Vector{Symbol}
end
