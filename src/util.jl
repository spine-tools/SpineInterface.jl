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

# Utility functions that are used in more than one file.
# (Everything that is used in only one file, we put it in the same file.)

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

"""
    _split_parameter_value_kwargs(p; <keyword arguments>)

Return a [`ParameterValue`](@ref) and keyword arguments for it after class filtering.

# Keyword arguments
  - _strict=true: whether to emit a warning if no entity matches the given kwargs
  - _default=nothing: A value to return if the parameter is not specified for the entity matching the kwargs.
    If not given, then the default value of the parameter as specified in the DB is returned.
"""
function _split_parameter_value_kwargs(p::Parameter; _strict=true, _default=nothing, kwargs...)
    _strict &= _default === nothing
    # The search stops when a parameter value is found in a class
    for class in sort(p.classes; by=_dimensionality, rev=true)
        # Split kwargs into class and parameter kwargs.
        new_kwargs = _nt_drop((;kwargs...), _dimension_names(class))
        entity = _entity_key(_nt_drop((;kwargs...), keys(new_kwargs)))
        if isnothing(entity)
            continue
        elseif length(entity) == 1 # If entity is an object
            entity = only(entity)
        end
        parameter_values = _get_pvals(class.parameter_values, entity)
        parameter_values === nothing && continue
        return _get(parameter_values, p.name, class.parameter_defaults, _default), new_kwargs
    end
    _strict && @warn("can't find a value of $p for argument(s) $((; kwargs...))")
    nothing
end

"""
    _entity_key(r::RelationshipLike)

Convert a [`RelationshipLike`](@ref) into [`ObjectTupleLike`](@ref).

Checks if the keys are consistent, returns nothing if not.
"""
function _entity_key(r::RelationshipLike)
    if isempty(r) || any(keys(r) .!= getfield.(values(r), :class_name))
        return nothing
    else
        return values(r)
    end
end
_entity_key(r::NamedTuple{}) = nothing # Tasku: Weird case in unit tests.
_entity_key(otl::ObjectTupleLike) = otl
_entity_key(o::ObjectLike) = o

_dimension_names(x::ObjectClass) = (x.name,)
_dimension_names(x::RelationshipClass) = (x.valid_filter_dimensions...,)

_dimensionality(x::ObjectClass) = 0
_dimensionality(x::RelationshipClass) = length(first(x.relationships))

_get_pvals(pvals_by_entity, ::Nothing) = nothing
_get_pvals(pvals_by_entity, object) = _do_get_pvals(pvals_by_entity, object)
function _get_pvals(pvals_by_entity, objects::Tuple)
    any(x === nothing for x in objects) && return nothing
    _do_get_pvals(pvals_by_entity, objects)
end

function _do_get_pvals(pvals_by_entity, entity)
    get(pvals_by_entity, entity) do
        _find_match(pvals_by_entity, entity)
    end
end

_find_match(pvals_by_entity, x) = nothing
_find_match(pvals_by_entity, ::Missing) = nothing
_find_match(pvals_by_entity, ::NTuple{N,Missing}) where N = nothing
function _find_match(pvals_by_entity, objects::Tuple)
    any(x === missing for x in objects) || return nothing
    matched = nothing
    for (key, pvals) in pvals_by_entity
        if _matches(key, objects)
            matched === nothing || return nothing  # If we find a second match, return nothing - we want a unique match
            matched = pvals
        end
    end
    matched
end

_matches(key::Tuple, objects::Tuple) = all(_matches(k, obj) for (k, obj) in zip(key, objects))
_matches(k, ::Missing) = true
_matches(k, obj) = k == obj

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

function _append_relationships!(rc, rels)
    isempty(rels) && return
    new_dim_names = setdiff(
        rc.valid_filter_dimensions, _valid_dimensions_from_rels(rels)
    )
    append!(rc.valid_filter_dimensions, new_dim_names)
    append!(rc.relationships, rels)
    nothing
end

function _valid_dimensions_from_rels(rels::Vector{<:RelationshipLike})
    unique(Iterators.flatten(keys.(rels)))
end
_valid_dimensions_from_rels(::Vector{Union{}}) = Vector{Symbol}() # Tasku: Weird unit test case.
_valid_dimensions_from_rels(v::Vector{Any}) = ( # Tasku: Another weird unit test case.
    isempty(v) ? Vector{Symbol}() : error("No valid dimension names for empty relationship vector!") 
)

"""
    _nt_drop(nt::NamedTuple, keys::Tuple)

Return `nt` with `keys` dropped.
"""
_nt_drop(nt::NamedTuple, keys::Tuple) = Base.structdiff(nt, NamedTuple{(keys...,)})