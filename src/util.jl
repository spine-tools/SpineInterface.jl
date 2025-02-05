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

# Keyword arguments
  - _strict=true: whether to emit a warning if no entity matches the given kwargs
  - _default=nothing: A value to return if the parameter is not specified for the entity matching the kwargs.
    If not given, then the default value of the parameter as specified in the DB is returned.
"""
function _split_parameter_value_kwargs(p::Parameter; _strict=true, _default=nothing, kwargs...)
    _strict &= _default === nothing
    # The search stops when a parameter value is found in a class
    for class in sort(p.classes; by=_dimensionality, rev=true)
        entity, new_kwargs = Base.invokelatest(class._split_kwargs[]; kwargs...)
        parameter_values = _get_pvals(class.parameter_values, entity)
        parameter_values === nothing && continue
        return _get(parameter_values, p.name, class.parameter_defaults, _default), new_kwargs
    end
    _strict && @warn("can't find a value of $p for argument(s) $((; kwargs...))")
    nothing
end

_dimension_names(x::EntityClass) = x.object_class_names

_dimensionality(x::EntityClass) = length(x.dimension_names)

_get_pvals(pvals_by_entity, ::Nothing) = nothing
_get_pvals(pvals_by_entity, object::Entity) = _do_get_pvals(pvals_by_entity, (object,))
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

_do_realize(x, _upd) = x
_do_realize(call::Call, upd) = _do_realize(call.func, call, upd)
_do_realize(::Nothing, call, _upd) = realize(call.args[1])
function _do_realize(pv::T, call, upd) where T<:ParameterValue
    pv(upd; call.kwargs...)
end
function _do_realize(::T, call, upd) where T<:Function
    current = _CallNode(call, nothing, -1)
    while true
        vals = [child.value[] for child in current.children]
        if !isempty(vals)
            # children already visited, compute value
            current.value[] = current.call.func(vals...)
        elseif current.call.func isa Function
            # visit children
            current = _first_child(current)
            continue
        else
            # no children, realize value
            current.value[] = realize(current.call, upd)
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

function _refresh_metadata!(pval::ParameterValue)
    empty!(pval.metadata)
    merge!(pval.metadata, _parameter_value_metadata(pval.value))
end

function _add_update(t::TimeSlice, timeout, upd)
    lock(t.updates_lock) do
        t.updates[upd] = timeout
    end
end

function _append_relationships!(rc, rels)
    isempty(rels) && return
    delete!(rc.row_map, rc.name)  # delete memoized rows
    offset = length(rc.relationships)
    for cls_name in rc.object_class_names
        oc_row_map = get!(rc.row_map, cls_name, Dict())
        for (row, rel) in enumerate(rels)
            obj = getproperty(rel, cls_name)
            push!(get!(oc_row_map, obj, []), offset + row)
        end
    end
    append!(rc.relationships, rels)
    nothing
end

function _make_split_kwargs(name::Symbol)
    eval(
        Expr(
            :->,
            Expr(:tuple, Expr(:parameters, Expr(:kw, name, :missing), :(kwargs...))),
            Expr(:block, Expr(:tuple, name, :kwargs)),
        )
    )
end
function _make_split_kwargs(names::Vector{Symbol})
    eval(
        Expr(
            :->,
            Expr(:tuple, Expr(:parameters, (Expr(:kw, n, :missing) for n in names)..., :(kwargs...))),
            Expr(:block, Expr(:tuple, Expr(:tuple, names...), :kwargs)),
        )
    )
end

"""
Return the list of "byelemenents" (aka leaf elements) for a given [`Entity`](@ref).
"""
function _recursive_byelement_list(entity::Entity)
    isempty(entity.element_list) && return [entity]
    byelement_list = vcat(_recursive_byelement_list.(entity.element_list)...)
    return byelement_list::Vector{Entity}
end