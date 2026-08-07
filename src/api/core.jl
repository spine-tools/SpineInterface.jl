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

"""
    anything
using Base: SizeUnknown

The singleton instance of type [`Anything`](@ref), used to specify *all-pass* filters
in calls to [`RelationshipClass()`](@ref).
"""
const anything = Anything()

"""
    (<oc>::ObjectClass)(;<keyword arguments>)

An `Array` of [`Object`](@ref) instances corresponding to the objects in class `oc`.

# Arguments

For each parameter associated to `oc` in the database there is a keyword argument
named after it. The purpose is to filter the result by specific values of that parameter.

# Examples

```jldoctest
julia> using SpineInterface;


julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");


julia> using_spinedb(url)


julia> sort(node())
5-element Vector{Union{Int64, Object, TimeSlice}}:
 Dublin
 Espoo
 Leuven
 Nimes
 Sthlm

julia> commodity(state_of_matter=:gas)
1-element Vector{Union{Int64, Object, TimeSlice}}:
 wind
```
"""
function (oc::ObjectClass)(; kwargs...)
    isempty(kwargs) && return collect(values(oc.objects))
    collect(Iterators.filter(o -> value_filter_condition(oc.vertex, o.name, kwargs), values(oc.objects)))
end
function (oc::ObjectClass)(name::Symbol)
    get(oc.objects, name, nothing)
end
(oc::ObjectClass)(name::String) = oc(Symbol(name))

function as_object(atom::Atom, object_classes)
    class = object_classes[atom.first]
    class.objects[atom.second]
end

function objects_to_selector(class_label::Symbol, ::Anything)
    class_label => anything
end
function objects_to_selector(class_label::Symbol, object::Object)
    class_label => object.name
end
function objects_to_selector(class_label::Symbol, objects)
    Tuple(class_label => o.name for o in objects)
end

const Selector = Union{Atom, AnyAtomInClass, MultiAtomSelector, Anything}

struct EntitySelectors
    class::RelationshipClass
    legacy_selector
end

function Base.eltype(::Type{EntitySelectors})
    Vector{Selector}
end

function Base.IteratorSize(::Type{EntitySelectors})
    Base.SizeUnknown()
end

function Base.iterate(iter::EntitySelectors, state=1)
    if state > length(iter.class.dimension_combinations)
        return nothing
    end
    combination = iter.class.dimension_combinations[state]
    selector::Vector{Selector} = [anything for _ in 1:atomic_dimensionality(iter.class.vertex)]
    combination_start = 1
    problem = false
    for (class_label, objects) in iter.legacy_selector
        dimension_i = findfirst(d -> d == class_label, combination)
        if isnothing(dimension_i)
            continue
        elseif dimension_i < combination_start
            problem = true
            break # Break if the dimensions are out of order
        elseif isnothing(objects) || isempty(objects)
            problem = true
            break # Break if a selector is nothing or empty, needs to be after dimension check to accommodate parameter value kwargs
        end
        intact_class_label = iter.class.intact_dimension_combinations[state][dimension_i]
        selector[dimension_i] = objects_to_selector(intact_class_label, objects)
        combination_start = dimension_i + 1
    end
    if !all(s -> s === anything, selector) && !problem
        selector, state + 1
    else
        iterate(iter, state + 1)
    end
end

"""
    (<rc>::RelationshipClass)(;<keyword arguments>)

An `Array` of [`Object`](@ref) tuples corresponding to the relationships of class `rc`.

# Arguments

  - For each object class in `rc` there is a keyword argument named after it.
    The purpose is to filter the result by an object or list of objects of that class,
    or to accept all objects of that class by specifying `anything` for this argument.
  - `_compact::Bool=true`: whether or not filtered object classes should be removed from the resulting tuples.
  - `_default=[]`: the default value to return in case no relationship passes the filter.

# Examples

```jldoctest
julia> using SpineInterface;


julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");


julia> using_spinedb(url)


julia> sort(node__commodity())
5-element Vector{NamedTuple{K, V} where {K, V<:Tuple{Union{Int64, Object, TimeSlice}, Vararg{Union{Int64, Object, TimeSlice}}}}}:
 (node = Dublin, commodity = wind)
 (node = Espoo, commodity = wind)
 (node = Leuven, commodity = wind)
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=commodity(:water))
2-element Vector{Object}:
 Nimes
 Sthlm

julia> node__commodity(node=(node(:Dublin), node(:Espoo)))
1-element Vector{Object}:
 wind

julia> sort(node__commodity(node=anything))
2-element Vector{Object}:
 water
 wind

julia> collect(node__commodity(commodity=commodity(:water), _compact=false))
2-element Vector{@NamedTuple{node::Object, commodity::Object}}:
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)
# `sort()` doesn't work with Base.Generator, use `collect()` instead.

julia> node__commodity(commodity=commodity(:gas), _default=:nogas)
:nogas
```
"""
function (rc::RelationshipClass)(; _compact::Bool=true, _default::Any=EntityLike[], kwargs...)
    if isempty(kwargs)
        return collect(
            NamedTuple(AtomsAsObjects(rc.object_classes, atoms))
            for atoms in all_atom_tuples(rc.vertex.relationship_graph, rc.vertex.entities)
        )
    end
    relationships = Vector{Union{Object, RelationshipLike}}()
    for selector in Set(EntitySelectors(rc, kwargs))
        for atoms in find_relationships(rc.vertex, selector...)
            object_tuple = NamedTuple(AtomsAsObjects(rc.object_classes, atoms))
            if _compact
                object_tuple = (; (class_name => object for (class_name, object) in pairs(object_tuple) if !in(class_name, keys(kwargs)))...)
            end
            if length(object_tuple) == 0
                break
            elseif length(object_tuple) == 1
                push!(relationships, object_tuple[1])
            else
                push!(relationships, object_tuple)
            end
        end
    end
    if isempty(relationships)
        return _default
    end
    relationships
end

function occurrences_before(v, x, i)
    count(e -> e.first == x, v[1:i - 1])
end

function occurrences_after(v, x, i)
    count(e -> e.first == x, v[i + 1: end])
end

struct AtomsAsObjects
    object_classes::Dict{Symbol, ObjectClass}
    atoms::AtomTuple
    unambiguous_class_names::Vector{Symbol}
    function AtomsAsObjects(object_classes, atoms)
        class_names = Vector{Symbol}(undef, length(atoms))
        for (i, atom) in enumerate(atoms)
            prior_n = occurrences_before(atoms, atom.first, i)
            post_n = occurrences_after(atoms, atom.first, i)
            if prior_n + post_n > 0
                unambiguous_name = Symbol("$(atom.first)$(1 + prior_n)")
            else
                unambiguous_name = atom.first
            end
            class_names[i] = unambiguous_name
        end
        new(object_classes, atoms, class_names)
    end
end

function Base.eltype(::Type{AtomsAsObjects})
    Pair{Symbol, Object}
end

function Base.length(iter::AtomsAsObjects)
    length(iter.atoms)
end

function Base.iterate(iter::AtomsAsObjects, state=1)
    if state > length(iter.atoms)
        return nothing
    end
    atom = iter.atoms[state]
    iter.unambiguous_class_names[state] => as_object(atom, iter.object_classes), state + 1
end

const LegacySelector = Pair{Symbol, Union{Object, Nothing}}

function fix_legacy_class_selector(class::ObjectClass, legacy_selector)
    object = get(legacy_selector, class.name, nothing)
    if !isnothing(object)
        [class.name => object]
    else
        nothing
    end
end
function fix_legacy_class_selector(class::RelationshipClass, legacy_selector)
    selector = Vector{LegacySelector}()
    sizehint!(selector, atomic_dimensionality(class.vertex))
    current_i = 1
    for (class_label, object) in legacy_selector
        i = findnext(labels -> class_label in labels, class.vertex.atomic_dimension_choices, current_i)
        if !isnothing(i)
            current_i = i
            push!(selector, class_label => object)
        else
            class_name = String(class_label)
            if !isdigit(class_name[end])
                continue
            end
            intact_label = Symbol(class_name[1:end-1])
            i = findnext(labels -> intact_label in labels, class.vertex.atomic_dimension_choices, current_i)
            if !isnothing(i)
                current_i = i
                push!(selector, class_label => object)
            end
        end
    end
    selector
end

function modernize_entity_selector(classes, kwargs)
    entity_selectors = Vector{Pair{Symbol, Vector{LegacySelector}}}()
    for class in classes
        selector = fix_legacy_class_selector(class, kwargs)
        if !isnothing(selector)
            push!(entity_selectors, class.name => selector)
        end
    end
    entity_selectors
end

function get_concrete_class(superclass::Superclass, label::Symbol)
    get(superclass.object_classes, label) do
        superclass.relationship_classes[label]
    end
end

function is_legacy_selector_compatible(legacy_selector, vertex::ObjectClassVertex)
    length(legacy_selector) < 2
end
function is_legacy_selector_compatible(legacy_selector, vertex::RelationshipClassVertex)
    if length(legacy_selector) != length(vertex.atomic_dimension_choices)
        return true
    end
    for (class_label, dimension_choices) in zip(keys(legacy_selector), vertex.atomic_dimension_choices)
        if class_label in dimension_choices
            continue
        end
        class_name = String(class_label)
        if !isdigit(class_name[end])
            return false
        end
        intact_label = Symbol(class_name[1:end - 1])
        if !in(intact_label, dimension_choices)
            return false
        end
    end
    true
end

function (superclass::Superclass)(; _compact::Bool=true, _default::Any=EntityLike[], kwargs...)
    entities = []
    for subclass_label in ConcreteSubclassLabels(superclass.entity_class_graph, superclass.name)
        subclass_vertex = superclass.entity_class_graph[subclass_label]
        if !isempty(kwargs) && !is_legacy_selector_compatible(kwargs, subclass_vertex)
            continue
        end
        append!(entities, get_concrete_class(superclass, subclass_label)(; _compact=_compact, _default=_default, kwargs...))
    end
    entities
end

function entity_selectors(class::ObjectClass, legacy_selector)
    sel = get(legacy_selector, class.name, nothing) # Handle shared parameter names across classes.
    isnothing(sel) ? tuple() : (sel.name,)
end
function entity_selectors(class::RelationshipClass, legacy_selector)
    EntitySelectors(class, legacy_selector)
end

function parameter_entity_label(vertex::ObjectClassVertex, selector)
    selector
end
function parameter_entity_label(vertex::RelationshipClassVertex, selector)
    if any(s === anything || s.second === anything for s in selector)
        unique_label = nothing
        for relationship_label in keys(vertex.parameter_values)
            hit = false
            for (s, atom) in zip(selector, RelationshipAtoms(vertex.relationship_graph, relationship_label))
                if s === anything || s.second === Anything
                    continue
                end
                if s != atom
                    hit = false
                    break
                end
                hit = true
            end
            if hit
                if !isnothing(unique_label)
                    return nothing
                end
                unique_label = relationship_label
            end
        end
        return unique_label
    end
    relationship_label(vertex.relationship_graph, selector...)
end

function find_value_instance(parameter_name, vertex, entity_selector, _default)
    entity_label = parameter_entity_label(vertex, entity_selector)
    values = get(vertex.parameter_values, entity_label, nothing)
    if !isnothing(values)
        value = get(values, parameter_name, nothing)
        if !isnothing(value)
            value
        elseif isnothing(_default)
            vertex.parameter_defaults[parameter_name]
        else
            parameter_value(_default)
        end
    else
        nothing
    end
end

struct LegacySelectorKeys
    class::RelationshipClass
    selector_i::Int
    selector_length::Int
    function LegacySelectorKeys(class, entity_selector)
        for (selector_i, combination) in enumerate(class.intact_dimension_combinations)
            if all(s !== anything ? s.first == c : true for (s, c) in zip(entity_selector, combination))
                return new(class, selector_i, length(entity_selector))
            end
        end
        error("this should be unreachable")
    end
end

function Base.eltype(::Type{LegacySelectorKeys})
    Symbol
end

function Base.length(iter::LegacySelectorKeys)
    length(iter.selector_length)
end

function Base.iterate(iter::LegacySelectorKeys, state=1)
    if state > iter.selector_length
        return nothing
    end
    iter.class.dimension_combinations[iter.selector_i][state], state + 1
end

function legacy_selector_keys(class::ObjectClass, entity_selector)
    (class.name,)
end
function legacy_selector_keys(class::RelationshipClass, entity_selector)
    LegacySelectorKeys(class, entity_selector)
end

function selector_hit_count(selector)
    count(s !== anything for s in selector)
end
function selector_hit_count(selector::Symbol)
    1
end

function unique_value_instance(parameter_name, classes, _default, kwargs)
    instance = nothing
    instance_kwargs = nothing
    max_selector_hits = 0
    selector_hit_duplicity = 0
    for class in classes
        for selector in entity_selectors(class, kwargs)
            selector_hits = selector_hit_count(selector)
            if selector_hits < max_selector_hits
                continue
            end
            selected_value = find_value_instance(parameter_name, class.vertex, selector, _default)
            if !isnothing(selected_value)
                if selector_hits > max_selector_hits
                    max_selector_hits = selector_hits
                    selector_hit_duplicity = 1
                    instance = selected_value
                    instance_kwargs = (k => v for (k, v) in pairs(kwargs) if !in(v, legacy_selector_keys(class, selector)))
                else
                    selector_hit_duplicity += 1
                end
            end
        end
    end
    if selector_hit_duplicity > 1
        return nothing, nothing
    end
    instance, instance_kwargs
end

"""
    (<p>::Parameter)(;<keyword arguments>)

The value of parameter `p` for a given arguments.

# Arguments

  - For each object class associated with `p` there is a keyword argument named after it.
    The purpose is to retrieve the value of `p` for a specific object.
  - For each relationship class associated with `p`, there is a keyword argument named after each of the
    object classes involved in it. The purpose is to retrieve the value of `p` for a specific relationship.
  - `i::Int64`: a specific index to retrieve in case of an array value (ignored otherwise).
  - `t::TimeSlice`: a specific time-index to retrieve in case of a time-varying value (ignored otherwise).
  - `inds`: indexes for navigating a `Map` (ignored otherwise). Tuples correspond to navigating nested `Maps`.
  - `_strict::Bool`: whether to raise an error or return `nothing` if the parameter is not specified for the given arguments.

# Examples

```jldoctest
julia> using SpineInterface;


julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");


julia> using_spinedb(url)


julia> tax_net_flow(node=node(:Sthlm), commodity=commodity(:water))
4

julia> demand(node=node(:Sthlm))
3-element Vector{Float64}:
 21.0
 17.0
  9.0

julia> demand(node=node(:Sthlm), i=2)
17.0
```
"""
function (p::Parameter)(; _strict=true, _default=nothing, kwargs...)
    value = nothing
    value_instance, value_kwargs = unique_value_instance(p.name, classes(p), _default, kwargs)
    if !isnothing(value_instance)
        value = value_instance(; value_kwargs...)
    end
    if !isnothing(value)
        value
    else
        if _strict
            @warn("can't find a value of $p for argument(s) $((; kwargs...))")
        end
        _default
    end
end

const __value_translator = Ref{Union{Nothing,Function}}(nothing)

function set_value_translator(translator)
    __value_translator[] = translator
end

function _value_translator()
    __value_translator[]
end

"""
    (<pv>::ParameterValue)(upd; <keyword arguments>)

A value from `pv`.
"""
function (pv::ParameterValue)(; kwargs...)
    pv(kwargs)
end
(pv::ParameterValue{T} where T<:_Scalar)(kwargs, upd=nothing) = pv.value
function (pv::ParameterValue{T} where T<:Array)(kwargs, upd=nothing)
    _get_value(pv, :i, get(kwargs, :i, nothing), upd)
end
function (pv::ParameterValue{T} where T<:Union{TimePattern,TimeSeries})(kwargs, upd=nothing)
    _get_value(pv, :t, get(kwargs, :t, nothing), upd)
end
function (pv::ParameterValue{T} where {T<:Map})(kwargs, upd=nothing)
    isempty(kwargs) && return _recursive_inner_value(pv.value)
    current_pv = pv
    resolved = 0
    while true
        found = false
        for (i, (kw, arg)) in enumerate(pairs(kwargs))
            iszero(resolved & 2^(i-1)) || continue
            if current_pv.value isa Map
                arg = translate_map_pv_arg!(arg, upd)
            end
            x = try
                _get_value(current_pv, kw, arg, upd)
            catch err
                err isa MethodError || rethrow()
                nothing
            end
            x === nothing && continue
            if x isa ParameterValue
                resolved |= 2^(i-1)
                current_pv = _translated_pv(x)
                found = true
                break
            else
                return x
            end
        end
        found || break
    end
    _recursive_inner_value(current_pv)
end
function (pv::ParameterValue{T} where T<:Symbol)(kwargs, upd=nothing)
    translated_pv = _translated_pv(pv)
    translated_pv === pv && return pv.value
    translated_pv(kwargs, upd)
end

function _translated_pv(pv::ParameterValue{T}) where T<:Symbol
    translator = _value_translator()
    translator === nothing && return pv
    translated_value = translator(pv.value)
    translated_value === nothing && return pv
    parameter_value(translated_value)
end
_translated_pv(pv::ParameterValue) = pv

_recursive_inner_value(x) = x
_recursive_inner_value(x::ParameterValue) = _recursive_inner_value(x.value)
function _recursive_inner_value(x::Map)
    Map(x.indexes, _recursive_inner_value.(x.values))
end

# Array
_get_value(pv::ParameterValue{T}, _kw, ::Nothing, upd) where T<:Array = pv.value
_get_value(pv::ParameterValue{T}, _kw, i::Int64, upd) where T<:Array = get(pv.value, i, nothing)
# TimePattern
_get_value(pv::ParameterValue{T}, _kw, ::Nothing, upd) where T<:TimePattern = pv.value
function _get_value(pv::ParameterValue{T}, _kw, t::DateTime, upd) where T<:TimePattern
    _get_value(pv, _kw, TimeSlice(t, t), upd)
end
function _get_value(pv::ParameterValue{T}, _kw, t::TimeSlice, upd) where T<:TimePattern
    vals = [val for (tp, val) in pv.value if overlaps(t, tp)]
    if upd !== nothing
        timeout = if isempty(vals)
            Second(0)
        else
            min(
                floor(start(t), pv.precision) + pv.precision(1) - start(t),
                ceil(end_(t), pv.precision) + Millisecond(1) - end_(t)
            )
        end
        _add_update!(t, timeout, upd)
    end
    isempty(vals) && return NaN
    mean(vals)
end
# TimeSeries
_get_value(pv::ParameterValue{T}, _kw, ::Nothing, upd) where T<:TimeSeries = pv.value
function _get_value(pv::ParameterValue{T}, _kw, t, upd) where T<:TimeSeries
    if pv.value.repeat
        _get_repeating_time_series_value(pv, t, upd)
    else
        _get_time_series_value(pv, t, upd)
    end
end
# Map
function _get_value(pv::ParameterValue{T}, kw, arg, upd) where {T<:Map}
    i = _search_equal(pv.value.indexes, arg)
    i === nothing && return nothing
    pv.value.values[i]
end
function _get_value(pv::ParameterValue{T}, kw, arg::Object, upd) where {V,T<:Map{Symbol,V}}
    i = _search_equal(pv.value.indexes, arg.name)
    i === nothing && return nothing
    pv.value.values[i]
end
function _get_value(pv::ParameterValue{T}, kw, arg::K, upd) where {V,K<:Union{DateTime,Float64},T<:Map{K,V}}
    i = _search_nearest(pv.value.indexes, arg)
    i === nothing && return nothing
    pv.value.values[i]
end

function translate_map_pv_arg!(arg::Pair{TimeSlice,V}, upd) where {V}
    t, arg = arg
    if upd !== nothing
        _add_update!(t, Minute(-1), upd)
    end
    translate_map_pv_arg!(arg, upd)
end
function translate_map_pv_arg!(arg::Base.RefValue, upd)
    translate_map_pv_arg!(arg[], upd)
end
translate_map_pv_arg!(arg, _upd) = arg

function _get_time_series_value(pv, t::DateTime, upd)
    pv.value.ignore_year && (t -= Year(t))
    t < pv.value.indexes[1] && return NaN
    t > pv.value.indexes[end] && !pv.value.ignore_year && return NaN
    pv.value.values[max(1, searchsortedlast(pv.value.indexes, t))]
end
function _get_time_series_value(pv, t::TimeSlice, upd)
    t_start, t_end = if pv.value.ignore_year
        start(t) - Year(start(t)), end_(t) - Year(start(t))
    else
        start(t), end_(t)
    end
    a, b = _search_overlap(pv.value, t_start, t_end)
    if upd !== nothing
        timeout = _timeout(pv.value, t_start, t_end, a, b)
        _add_update!(t, timeout, upd)
    end
    t_end <= pv.value.indexes[1] && return NaN
    t_start > pv.value.indexes[end] && !pv.value.ignore_year && return NaN
    mean(Iterators.filter(!isnan, view(pv.value.values, a:b)))
end

function _get_repeating_time_series_value(pv, t::DateTime, upd)
    pv.value.ignore_year && (t -= Year(t))
    mismatch = t - pv.value.indexes[1]
    reps = fld(mismatch, pv.span)
    t -= reps * pv.span
    pv.value.values[max(1, searchsortedlast(pv.value.indexes, t))]
end
function _get_repeating_time_series_value(pv, t::TimeSlice, upd)
    t_start, t_end = if pv.value.ignore_year
        start(t) - Year(start(t)), end_(t) - Year(start(t))
    else
        start(t), end_(t)
    end
    mismatch_start = t_start - pv.value.indexes[1]
    mismatch_end = t_end - pv.value.indexes[1]
    reps_start = fld(mismatch_start, pv.span)
    reps_end = fld(mismatch_end, pv.span)
    t_start -= reps_start * pv.span
    t_end -= reps_end * pv.span
    a, b = _search_overlap(pv.value, t_start, t_end)
    if upd !== nothing
        timeout = _timeout(pv.value, t_start, t_end, a, b)
        _add_update!(t, timeout, upd)
    end
    reps = reps_end - reps_start
    reps == 0 && return mean(Iterators.filter(!isnan, view(pv.value.values, a:b)))
    avals = view(pv.value.values, a:lastindex(pv.value.values))
    bvals = view(pv.value.values, 1:b)
    asum = sum(Iterators.filter(!isnan, avals))
    bsum = sum(Iterators.filter(!isnan, bvals))
    alen = count(!isnan, avals)
    blen = count(!isnan, bvals)
    (asum + bsum + (reps - 1) * pv.valsum) / (alen + blen + (reps - 1) * pv.len)
end

function _search_overlap(ts::TimeSeries, t_start::DateTime, t_end::DateTime)
    a = if t_start < ts.indexes[1]
        1
    elseif t_start > ts.indexes[end]
        length(ts.indexes)
    else
        searchsortedlast(ts.indexes, t_start)
    end
    b = searchsortedfirst(ts.indexes, t_end) - 1
    (a, b)
end

function _search_equal(arr::AbstractArray{T,1}, x::T) where {T}
    i = searchsortedfirst(arr, x)  # index of the first value in arr greater than or equal to x, length(arr) + 1 if none
    i <= length(arr) && arr[i] === x && return i
    nothing
end
_search_equal(arr, x) = nothing

function _search_nearest(arr::AbstractArray{T,1}, x::T) where {T}
    i = searchsortedlast(arr, x)  # index of the last value in arr less than or equal to x, 0 if none
    max(i, 1)
end
_search_nearest(arr, x) = nothing

_next_index(val::Union{TimeSeries,Map}, pos) = val.indexes[min(pos + 1, length(val.indexes))]

function _timeout(val::TimeSeries, t_start, t_end, a, b)
    min(_next_index(val, a) - t_start, _next_index(val, b) + Millisecond(1) - t_end)
end

members(::Anything) = anything
function members(objects)
    unique_members = Set{Object}()
    for object in objects
        if isempty(object.members)
            push!(unique_members, object)
        else
            union!(unique_members, object.members)
        end
    end
    collect(unique_members)
end

groups(x) = unique(group for obj in x for group in obj.groups)

function fill_with_atoms!(atoms, object_tuple, dimension_combination, intact_combination)
    for ((class_label, object), matching_label, intact_label) in zip(pairs(object_tuple), dimension_combination, intact_combination)
        if class_label != matching_label
            return false
        end
        push!(atoms, intact_label => object.name)
    end
    true
end

function object_tuple_to_atoms(object_tuple::RelationshipLike, class::RelationshipClass) # Typing prevents reaching the unreachable
    atoms = Vector{Atom}()
    sizehint!(atoms, length(object_tuple))
    for (combination_i, combination) in enumerate(class.dimension_combinations)
        intact_combination = class.intact_dimension_combinations[combination_i]
        if fill_with_atoms!(atoms, object_tuple, combination, intact_combination)
            return atoms
        else
            empty!(atoms)
        end
    end
    error("This code should be unreachable! Check your `object_tuple` class-object pairs.")
end

function relationship_label(class::RelationshipClass, object_tuple::NamedTuple)
    atoms = object_tuple_to_atoms(object_tuple, class)
    relationship_label(class.vertex.relationship_graph, atoms...)
end

# TimeSlice relationships are called in quite complex ways in SpineOpt...
# Similar to legacy relationship classes.
function _get_outneighbors(time_slice_graph::MetaGraphsNext.MetaGraph, slice::TimeSlice, names::Tuple{Symbol, Symbol}, ::Val{true}) # Dispatch based on `_compact`
    if haskey(time_slice_graph, slice)
        return MetaGraphsNext.outneighbor_labels(time_slice_graph, slice)
    else
        return ()
    end
end
function _get_outneighbors(time_slice_graph::MetaGraphsNext.MetaGraph, slice::TimeSlice, names::Tuple{Symbol, Symbol}, ::Val{false}) # Dispatch based on `_compact`
    return (NamedTuple{names}((slice, s)) for s in _get_outneighbors(time_slice_graph, slice, names, Val(true)))
end
function _get_inneighbors(time_slice_graph::MetaGraphsNext.MetaGraph, slice::TimeSlice, names::Tuple{Symbol, Symbol}, ::Val{true}) # Dispatch based on `_compact`
    if haskey(time_slice_graph, slice)
        return MetaGraphsNext.inneighbor_labels(time_slice_graph, slice)
    else
        return ()
    end
end
function _get_inneighbors(time_slice_graph::MetaGraphsNext.MetaGraph, slice::TimeSlice, names::Tuple{Symbol, Symbol}, ::Val{false}) # Dispatch based on `_compact`
    return (NamedTuple{names}((s, slice)) for s in _get_inneighbors(time_slice_graph, slice, names, Val(true)))
end
function _get_timeslices(neighbor_func::Function, time_slice_graph::MetaGraphsNext.MetaGraph, slice::TimeSlice, names::Tuple{Symbol, Symbol}, _compact::Bool)
    return neighbor_func(time_slice_graph, slice, names, Val(_compact))
end
function _get_timeslices(neighbor_func::Function, time_slice_graph::MetaGraphsNext.MetaGraph, slice::AbstractVector, names::Tuple{Symbol, Symbol}, _compact::Bool) # Potentially dangerous catch-all
    return Iterators.flatten(neighbor_func(time_slice_graph, s, names, Val(_compact)) for s in slice)
end

function (slice_relationships::TimeSliceRelationships)(; _compact=true, kwargs...)
    graph = slice_relationships.time_slice_graph
    names = (slice_relationships.preceding, slice_relationships.succeeding)
    _get_neighbors_map = Dict(
        names[1] => _get_outneighbors,
        names[2] => _get_inneighbors
    )
    all_kwargs_are_anything = all(v == anything for v in values(kwargs))
    # Handle annoying special cases...
    if isempty(kwargs) || (all_kwargs_are_anything && !_compact) # Need to return all relationships if no kwargs
        return collect(NamedTuple{names}(tup) for tup in MetaGraphsNext.edge_labels(graph))
    elseif any(isnothing(v) for v in values(kwargs))
        return Vector{TimeSlice}() # Return empty if any kwarg is `nothing`
    elseif length(kwargs) >= length(names) && _compact
        return Vector{TimeSlice}() # Return empty if too many filters with `_compact`
    elseif all_kwargs_are_anything && _compact
        ind = findfirst(only(kwargs).first != name for name in names)
        return unique(getindex.(MetaGraphsNext.edge_labels(graph), ind)) # Return the unique timeslices for the other half.
    end
    # Only now do we have to do filtering
    return intersect( # This might waste memory, and I'm not sure how to type this Vector{TimeSlice}
        (
            _get_timeslices(_get_neighbors_map[name], graph, slice, names, _compact)
            for (name, slice) in kwargs if slice != anything # No point in filtering `anything`s
        )...
    )
end

"""
    indices(p::Parameter, [c::Union{ObjectClass,RelationshipClass}]; kwargs...)

An iterator over all objects and relationships where the value of `p` is different than `nothing`.

# Arguments

  - For each object class where `p` is defined, there is a keyword argument named after it;
    similarly, for each relationship class where `p` is defined, there is a keyword argument
    named after each object class in it.
    The purpose of these arguments is to filter the result by an object or list of objects of an specific class,
    or to accept all objects of that class by specifying `anything` for the corresponding argument.

# Examples

```jldoctest
julia> using SpineInterface;


julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");


julia> using_spinedb(url)


julia> collect(indices(tax_net_flow))
1-element Vector{@NamedTuple{node::Object, commodity::Object}}:
 (node = Sthlm, commodity = water)

julia> collect(indices(demand))
5-element Vector{Object}:
 Dublin
 Espoo
 Leuven
 Nimes
 Sthlm
```
"""
function indices(p::Parameter; kwargs...)
    (ent for class in classes(p) for ent in indices(p, class; kwargs...) if is_legacy_selector_compatible(kwargs, class.vertex))
end
function indices(p::Parameter, class::ObjectClass; kwargs...)
    (
        ent
        for ent in values(class.objects)
        if _get(class.vertex.parameter_values[ent.name], p.name, class.vertex.parameter_defaults)() !== nothing
    )
end
function indices(p::Parameter, class::RelationshipClass; kwargs...)
    (
        ent
        for ent in class(; _compact=false, kwargs...)
        if _get(class.vertex.parameter_values[relationship_label(class, ent)], p.name, class.vertex.parameter_defaults)() !== nothing
    )
end

"""
    indices_as_tuples(p::Parameter[, c::EntityClass]; kwargs...)

Like `indices` but also yields tuples for single-dimensional entities.
"""
function indices_as_tuples(p::Parameter; kwargs...)
    (ent for class in classes(p) for ent in indices_as_tuples(p, class; kwargs...))
end
function indices_as_tuples(p::Parameter, class::ObjectClass; kwargs...)
    (
        (; class.name => ent)
        for ent in values(class.objects)
        if _get(class.vertex.parameter_values[ent.name], p.name, class.vertex.parameter_defaults)() !== nothing
    )
end
function indices_as_tuples(p::Parameter, class::RelationshipClass; kwargs...)
    indices(p, class; kwargs...)
end

classes(p::Parameter) = p.sorted_classes

struct ClassSize
    entity_class_graph::MetaGraphsNext.MetaGraph
end

function (c::ClassSize)(class::EntityClass)
    atomic_dimensionality(c.entity_class_graph, class.name)
end

function push_class!(p::Parameter, class::EntityClass)
    push!(p.sorted_classes, class)
    sort!(p.sorted_classes, by=ClassSize(class.entity_class_graph), rev=true)
end

"""
    add_objects!(object_class::ObjectClass, objects)

Add everything from `objects` that's not already in `object_class` into `object_class`.
Return the modified `object_class`.
"""
function add_objects!(object_class::ObjectClass, objects) # Support other iterables
    for object in objects
        if !in(object.name, keys(object_class.objects))
            add_object!(object_class, object)
        end
    end
    object_class
end

function add_object_parameter_values!(
    object_class::ObjectClass,
    parameter_values::Dict{Object, <:Dict{Symbol, <:ParameterValue}}; # Support mixed ParameterValue{T}s
    merge_values=false
)
    add_objects!(object_class, only.(keys(parameter_values)))
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    target_values = object_class.vertex.parameter_values
    for (obj, vals) in parameter_values
        obj = only(obj)
        do_merge!(target_values[obj.name], vals)
    end
end
function add_object_parameter_values!(
    object_class::ObjectClass,
    parameter_values::Dict{Symbol, <:Dict{Symbol, <:ParameterValue}};
    merge_values=false
)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    target_values = object_class.vertex.parameter_values
    for (object_label, values) in parameter_values
        do_merge!(target_values[object_label], values)
    end
end
function add_object_parameter_values!(oc::ObjectClass, pvs::Dict; merge_values=false)
    if isempty(pvs)
        return oc.vertex.parameter_values
    else
        throw(TypeError(
            :add_object_parameter_values!,
            "Only empty generic `Dict`s supported!",
            Dict{ObjectLike, Dict{Symbol, ParameterValue}},
            typeof(pvs)
        ))
    end
end

function merge_object_parameter_values!(target_vertex::ObjectClassVertex, source_vertex::ObjectClassVertex; merge_values=false)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    for (source_label, values) in source_vertex.parameter_values
        do_merge!(target_vertex.parameter_values[source_label], values)
    end
end

function add_object_parameter_defaults!(object_class::ObjectClass, parameter_defaults::Dict; merge_values=false)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    do_merge!(object_class.vertex.parameter_defaults, parameter_defaults)
end

function add_object!(object_class::ObjectClass, object::Object)
    add_entity!(object_class.vertex, object.name)
    object_class.objects[object.name] = object
    group_graph = object_class.vertex.entity_group_graph
    for group in object.groups
        add_entity_group_member!(group_graph, group, object) # Update group memberships on the fly
    end
    for member in object.members
        add_entity_group_member!(group_graph, object, member) # Update group memberships on the fly
    end
end

function intact_class_labels(class_labels, relationship_class::RelationshipClass)
    i = findfirst(relationship_class.dimension_combinations) do combination
        all(label == dimension for (label, dimension) in zip(class_labels, combination))
    end
    relationship_class.intact_dimension_combinations[i]
end

"""
    add_relationships!(relationship_class, relationships)

Add all relationships to `relationship_class` that are not already there.
Return the modified `relationship_class`.
"""
function add_relationships!(relationship_class::RelationshipClass, object_tuples::AbstractVector{T}) where T<:ObjectTupleLike
    atoms = Vector{Atom}(undef, atomic_dimensionality(relationship_class.vertex))
    for object_tuple in object_tuples
        for (i, object) in enumerate(object_tuple)
            class = object.class_name
            if isnothing(class)
                class = class_for_object(relationship_class.vertex, object.name, i)
            end
            atoms[i] = class => object.name
        end
        if !has_relationship(relationship_class.vertex.relationship_graph, atoms...)
            add_entity!(relationship_class.vertex, atoms...)
        end
    end
    relationship_class
end
function add_relationships!(relationship_class::RelationshipClass, objects::AbstractVector)
    atoms = Vector{Atom}(undef, atomic_dimensionality(relationship_class.vertex))
    intact_dimensions = nothing
    for elements in objects
        if isnothing(intact_dimensions)
            intact_dimensions = intact_class_labels(keys(elements), relationship_class)
        end
        for (i, object) in enumerate(elements)
            atoms[i] = intact_dimensions[i] => object.name
        end
        if !has_relationship(relationship_class.vertex.relationship_graph, atoms...)
            add_entity!(relationship_class.vertex, atoms...)
        end
    end
    relationship_class
end

function add_relationship_parameter_values!(
    target::RelationshipClass, source::RelationshipClass; merge_values=false
)
    for label in keys(source.vertex.parameter_values)
        add_entity!(target.vertex, RelationshipAtoms(source.vertex.relationship_graph, label)...)
    end
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    for (rel, vals) in source.vertex.parameter_values
        label = values(rel)
        do_merge!(target.vertex.parameter_values[label], vals)
    end
end
function add_relationship_parameter_values!( # SpineOpt uses ObjectTuples for some preprocessing for some reason.
    target::RelationshipClass, source::Dict{<:ObjectTupleLike, <:Dict{Symbol, <:ParameterValue}}; merge_values=false
)
    new_source = sizehint!(Dict{RelationshipLike, Dict{Symbol, ParameterValue}}(), length(source))
    for (objtup, pval) in source
        unique_classes = uniquefy_elements(getfield.(objtup, :class_name))
        new_source[NamedTuple{unique_classes}(objtup)] = pval
    end
    add_relationship_parameter_values!(target, new_source; merge_values=merge_values)
end
function add_relationship_parameter_values!(
    target::RelationshipClass, source::Dict{<:RelationshipLike, <:Dict{Symbol, <:ParameterValue}}; merge_values=false
)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    for (object_tuple, values) in source
        atoms = object_tuple_to_atoms(object_tuple, target)
        label = relationship_label(target.vertex.relationship_graph, atoms...)
        if isnothing(label)
            label = add_entity!(target.vertex, atoms...)
        end
        do_merge!(target.vertex.parameter_values[label], values)
    end
end
function add_relationship_parameter_values!(rc::RelationshipClass, pvs::Dict; merge_values=false)
    if isempty(pvs)
        return rc.vertex.parameter_values
    else
        throw(TypeError(
            :add_relationship_parameter_values!,
            "Only empty generic `Dict`s supported!",
            Dict{RelationshipLike, Dict{Symbol, ParameterValue}},
            typeof(pvs)
        ))
    end
end

function merge_relationship_parameter_values!(target_vertex::RelationshipClassVertex, source_vertex::RelationshipClassVertex; merge_values=false)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    for (source_label, values) in source_vertex.parameter_values
        target_label = relationship_label(target_vertex.relationship_graph, RelationshipAtoms(source_vertex.relationship_graph, source_label)...)
        do_merge!(target_vertex.parameter_values[target_label], values)
    end
end

function merge_parameter_defaults!(target, parameter_defaults::Dict, merge_values=false)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    do_merge!(target.vertex.parameter_defaults, parameter_defaults)
end

function add_relationship_parameter_defaults!(
    relationship_class::RelationshipClass, parameter_defaults::Dict; merge_values=false
)
    merge_parameter_defaults!(relationship_class, parameter_defaults, merge_values)
end

function add_relationship!(relationship_class::RelationshipClass, relationship::NamedTuple)
    add_entity!(relationship_class.vertex, object_tuple_to_atoms(relationship, relationship_class)...)
end

function add_parameter_values!(cls::ObjectClass, vals; kwargs...)
    add_object_parameter_values!(cls, vals; kwargs...)
end
function add_parameter_values!(cls::RelationshipClass, vals; kwargs...)
    add_relationship_parameter_values!(cls, vals; kwargs...)
end

"""
    object_classes(m=@__MODULE__)

A sequence of `ObjectClass`es generated by `using_spinedb` in the given module.
"""
object_classes(m=@__MODULE__) = _active_values(m, :_spine_object_classes)

"""
    relationship_classes(m=@__MODULE__)

A sequence of `RelationshipClass`es generated by `using_spinedb` in the given module.
"""
relationship_classes(m=@__MODULE__) = _active_values(m, :_spine_relationship_classes)

"""
    superclasses(m=@__MODULE__)

A sequence of [`Superclass`](@ref)es generated by [`using_spinedb`](@ref) in the given module.
"""
superclasses(m=@__MODULE__) = _active_values(m, :_spine_superclasses)

"""
    parameters(m=@__MODULE__)

A sequence of `Parameter`s generated by `using_spinedb` in the given module.
"""
parameters(m=@__MODULE__) = _active_values(m, :_spine_parameters)

"""
    object_class(name, m=@__MODULE__)

The `ObjectClass` of given name, generated by `using_spinedb` in the given module.
"""
object_class(name, m=@__MODULE__) = _active_value(m, :_spine_object_classes, name)

"""
    relationship_class(name, m=@__MODULE__)

The `RelationshipClass` of given name, generated by `using_spinedb` in the given module.
"""
relationship_class(name, m=@__MODULE__) = _active_value(m, :_spine_relationship_classes, name)

"""
    superclass(name, m=@__MODULE__)

The [`Superclass`](@ref) of the given `name` generated by [`using_spinedb`](@ref) in the given module.
"""
superclass(name, m=@__MODULE__) = _active_value(m, :_spine_superclasses, name)

"""
    parameter(name, m=@__MODULE__)

The `Parameter` of given name, generated by `using_spinedb` in the given module.
"""
parameter(name, m=@__MODULE__) = _active_value(m, :_spine_parameters, name)

_active_values(m, set_name) = [x for x in values(getproperty(m, set_name)) if _is_active(x)]

function _active_value(m, set_name, name)
    val = get(getproperty(m, set_name), name, nothing)
    _is_active(val) ? val : nothing
end

_is_active(x) = haskey(x.env_dict, _active_env())
_is_active(::Nothing) = false

"""
    difference(left, right)

A string summarizing the differences between the `left` and the right `Dict`s.
Both `left` and `right` are mappings from string to an array.
"""
function difference(left, right)
    function _entity_class_names(d)
        entity_classes = try
            d["entity_classes"]
        catch KeyError
            vcat(d["object_classes"], d["relationship_classes"])
        end
        first.(entity_classes)
    end

    function _parameter_names(d)
        parameter_definitions = try
            d["parameter_definitions"]
        catch KeyError
            vcat(d["object_parameters"], d["relationship_parameters"])
        end
        (x -> x[2]).(parameter_definitions)
    end

    diff = OrderedDict(
        "entity classes" => setdiff(_entity_class_names(left), _entity_class_names(right)),
        "parameters" => setdiff(_parameter_names(left), _parameter_names(right)),
    )
    header_size = maximum(length(key) for key in keys(diff))
    empty_header = repeat(" ", header_size)
    splitter = repeat(" ", 2)
    diff_str = ""
    for (key, value) in diff
        isempty(value) && continue
        header = lpad(key, header_size)
        diff_str *= "\n" * string(header, splitter, value[1], "\n")
        diff_str *= join([string(empty_header, splitter, x) for x in value[2:end]], "\n") * "\n"
    end
    diff_str
end

"""
    realize(call)

Perform the given call and return the result.
"""
function realize(call, upd=nothing)
    try
        _do_realize(call, upd)
    catch e
        err_msg = string("unable to evaluate expression:\n", call, "\n")
        rethrow(ErrorException("$err_msg$(sprint(showerror, e))"))
    end
end

dimensions(cls::RelationshipClass) = cls.object_class_names

const __active_env = Ref(:__base__)

function _activate_env(env::Symbol)
    __active_env[] = env
end

_active_env() = __active_env[]

function with_env(f::Function, env::Symbol)
    prev_env = _active_env()
    _activate_env(env)
    try
        return f()
    finally
        _activate_env(prev_env)
    end
end
