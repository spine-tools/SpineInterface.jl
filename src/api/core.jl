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

The singleton instance of type [`Anything`](@ref), used to specify *all-pass* filters
in calls to [`RelationshipClass()`](@ref).
"""
anything = Anything()

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
function (oc::ObjectClass)(args...; _compact::Bool=true, kwargs...)
    if isempty(oc.subclasses) # No subclasses -> Filter only this one.
        return _object_class_filtering(oc, args...; kwargs...)
    elseif length(oc.subclasses) == 1 # One subclass -> Filter only that one.
        return entity_class(only(oc.subclasses))(args...; _compact=_compact, kwargs...)
    else # Many subclasses -> Filter them all.
        if _compact
            return vcat(
                [cls(args...; _compact=_compact, kwargs...) for cls in entity_class.(oc.subclasses)]...
            )
        else # _compact=false sometimes returns iterators.
            return Iterators.flatten(
                cls(args...; _compact=_compact, kwargs...) for cls in entity_class.(oc.subclasses)
            )
        end
    end
end

function _object_class_filtering(oc::ObjectClass; kwargs...)
    isempty(kwargs) && return oc.objects
    function cond(o)
        for (p, v) in kwargs
            value = get(oc.parameter_values[o], p, get(oc.parameter_defaults, p, nothing))
            (value !== nothing && value() === v) || return false
        end
        true
    end
    filter(cond, oc.objects)
end
function _object_class_filtering(oc::ObjectClass, name::Symbol)
    i = findfirst(o -> o.name == name, oc.objects)
    !isnothing(i) && return oc.objects[i]
    nothing
end
_object_class_filtering(oc::ObjectClass, name::String) = oc(Symbol(name))

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
function (rc::RelationshipClass)(; _compact::Bool=true, _default::Any=[], kwargs...)
    isempty(kwargs) && return rc.relationships
    relationships = if !_compact
        _find_rels(rc; kwargs...)
    else
        object_class_names = setdiff(rc.object_class_names, keys(kwargs))
        if isempty(object_class_names)
            []
        elseif length(object_class_names) == 1
            unique(rel[object_class_names[1]] for rel in _find_rels(rc; kwargs...))
        else
            unique(
                (; zip(object_class_names, (rel[k] for k in object_class_names))...)
                for rel in _find_rels(rc; kwargs...)
            )
        end
    end
    if !isempty(relationships)
        relationships
    else
        _default
    end
end

_find_rels(rc; kwargs...) = _find_rels(rc, _find_rows(rc; kwargs...))
_find_rels(rc, rows) = (rc.relationships[row] for row in rows)
_find_rels(rc, ::Anything) = rc.relationships

function _find_rows(rc; kwargs...)
    lock(rc.row_map_lock) do
        memoized_rows = get!(rc.row_map, rc.name, Dict())
        get!(memoized_rows, kwargs) do
            _do_find_rows(rc; kwargs...)
        end
    end
end

function _do_find_rows(rc; kwargs...)
    rows = anything
    for (oc_name, objs) in kwargs
        oc_row_map = get(rc.row_map, oc_name, nothing)
        oc_row_map === nothing && return []
        oc_rows = _oc_rows(rc, oc_row_map, objs)
        oc_rows === anything && continue
        if rows === anything
            rows = collect(oc_rows)
        else
            intersect!(rows, oc_rows)
        end
        isempty(rows) && return []
    end
    rows
end

_oc_rows(_rc, oc_row_map, objs) = (row for obj in objs for row in get(oc_row_map, obj, ()))
_oc_rows(rc, _oc_row_map, ::Anything) = anything
_oc_rows(rc, _oc_row_map, ::Nothing) = []

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
    pv_new_kwargs = _split_parameter_value_kwargs(p; _strict=_strict, _default=_default, kwargs...)
    if !isnothing(pv_new_kwargs)
        pv, new_kwargs = pv_new_kwargs
        pv(; new_kwargs...)
    else
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
members(x) = unique(member for obj in x for member in obj.members)

groups(x) = unique(group for obj in x for group in obj.groups)

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
    (ent for class in p.classes for ent in indices(p, class; kwargs...))
end
function indices(p::Parameter, class::Union{ObjectClass,RelationshipClass}; kwargs...)
    (
        ent
        for ent in _entities(class; kwargs...)
        if _get(class.parameter_values[_entity_key(ent)], p.name, class.parameter_defaults)() !== nothing
    )
end

"""
    indices_as_tuples(p::Parameter, [c::Union{ObjectClass,RelationshipClass}]; kwargs...)

Like `indices` but also yields tuples for single-dimensional entities.
"""
function indices_as_tuples(p::Parameter; kwargs...)
    (ent for class in p.classes for ent in indices_as_tuples(p, class; kwargs...))
end
function indices_as_tuples(p::Parameter, class::Union{ObjectClass,RelationshipClass}; kwargs...)
    (
        _entity_tuple(ent, class)
        for ent in _entities(class; kwargs...)
        if _get(class.parameter_values[_entity_key(ent)], p.name, class.parameter_defaults)() !== nothing
    )
end

_entities(class::ObjectClass; kwargs...) = class()
_entities(class::RelationshipClass; kwargs...) = class(; _compact=false, kwargs...)

_entity_key(o::ObjectLike) = o
_entity_key(r::RelationshipLike) = tuple(r...)

_entity_tuple(o::ObjectLike, class) = (; (class.name => o,)...)
_entity_tuple(r::RelationshipLike, class) = r

classes(p::Parameter) = p.classes

push_class!(p::Parameter, class::Union{ObjectClass,RelationshipClass}) = push!(p.classes, class)

"""
    add_objects!(object_class, objects)

Remove from `objects` everything that's already in `object_class`, and append the rest.
Return the modified `object_class`.
"""
function add_objects!(object_class::ObjectClass, objects::Array)
    setdiff!(objects, object_class.objects)
    append!(object_class.objects, objects)
    merge!(object_class.parameter_values, Dict(obj => Dict() for obj in objects))
    object_class
end

function add_object_parameter_values!(object_class::ObjectClass, parameter_values::Dict; merge_values=false)
    add_objects!(object_class, only.(keys(parameter_values)))
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    for (obj, vals) in parameter_values
        obj = only(obj)
        do_merge!(object_class.parameter_values[obj], vals)
    end
end

function add_object_parameter_defaults!(object_class::ObjectClass, parameter_defaults::Dict; merge_values=false)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    do_merge!(object_class.parameter_defaults, parameter_defaults)
end

function add_object!(object_class::ObjectClass, object::ObjectLike)
    add_objects!(object_class, [object])
end

"""
    add_relationships!(relationship_class, relationships)

Remove from `relationships` everything that's already in `relationship_class`, and append the rest.
Return the modified `relationship_class`.
"""
function add_relationships!(relationship_class::RelationshipClass, object_tuples::Vector{T}) where T<:ObjectTupleLike
    relationships = [(; zip(relationship_class.object_class_names, obj_tup)...) for obj_tup in object_tuples]
    add_relationships!(relationship_class, relationships)
end
function add_relationships!(relationship_class::RelationshipClass, relationships::Vector)
    relationships = setdiff(relationships, relationship_class.relationships)
    _append_relationships!(relationship_class, relationships)
    merge!(relationship_class.parameter_values, Dict(values(rel) => Dict() for rel in relationships))
    relationship_class
end

function add_relationship_parameter_values!(
    relationship_class::RelationshipClass, parameter_values::Dict; merge_values=false
)
    add_relationships!(relationship_class, collect(keys(parameter_values)))
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    for (rel, vals) in parameter_values
        obj_tup = values(rel)
        do_merge!(relationship_class.parameter_values[obj_tup], vals)
    end
end

function add_relationship_parameter_defaults!(
    relationship_class::RelationshipClass, parameter_defaults::Dict; merge_values=false
)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    do_merge!(relationship_class.parameter_defaults, parameter_defaults)
end

function add_relationship!(relationship_class::RelationshipClass, relationship::RelationshipLike)
    add_relationships!(relationship_class, [relationship])
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
    entity_class(name, m=@__MODULE__)

The `ObjectClass` or `RelationshipClass` of given name, generated by `using_spinedb` in the given module.
"""
function entity_class(name, m=@__MODULE__)
    oc = object_class(name, m)
    isnothing(oc) ? relationship_class(name, m) : oc
end

"""
    parameter(name, m=@__MODULE__)

The `Parameter` of given name, generated by `using_spinedb` in the given module.
"""
parameter(name, m=@__MODULE__) = _active_value(m, :_spine_parameters, name)

_active_values(m, set_name) = [x for x in values(_getproperty(m, set_name, Dict())) if _is_active(x)]

function _active_value(m, set_name, name)
    val = get(_getproperty(m, set_name, Dict()), name, nothing)
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

function add_dimension!(cls::RelationshipClass, name::Symbol, obj)
    push!(cls.object_class_names, name)
    push!(cls.intact_object_class_names, name)
    map!(rel -> (; rel..., Dict(name => obj)...), cls.relationships, cls.relationships)
    for rel in collect(keys(cls.parameter_values))
        new_rel = (rel..., obj)
        cls.parameter_values[new_rel] = pop!(cls.parameter_values, rel)
    end
    cls.row_map[name] = Dict(obj => collect(1:length(cls.relationships)))
    delete!(cls.row_map, cls.name)  # delete memoized rows
    cls._split_kwargs[] = _make_split_kwargs(cls.object_class_names)
    nothing
end

"""
    reorder_dimensions(name::Symbol, cls::RelationshipClass, dims::Vector)

Create a new class `name` by reordering the dimensions of `cls`.

`dims` indicates the new desired order for the dimensions,
and can be either a `Vector{Symbol}` or `Vector{Integer}`.
Note that `dims` needs to correspond to the `object_class_names`
field, not the `intact_object_class_names` field!

Returns a new [`RelationshipClass`](@ref) with the reordered dimensions.

See also [`reorder_dimensions!`](@ref).
"""
function reorder_dimensions(name::Symbol, cls::RelationshipClass, dims::Vector)
    return reorder_dimensions(name, cls.env_dict[_active_env()], dims)
end
function reorder_dimensions(name::Symbol, _cls::_RelationshipClass, dims::Vector{Symbol})
    perm = _find_permutation(dims, _cls.object_class_names)
    return reorder_dimensions(name, _cls, perm)
end
function reorder_dimensions(name::Symbol, _cls::_RelationshipClass, perm::Vector{<:Integer})
    new_intact_cls_names = _cls.intact_object_class_names[perm]
    return RelationshipClass(
        name,
        new_intact_cls_names,
        [Tuple(objtup[i] for i in perm) for objtup in _cls.relationships],
        Dict(
            Tuple(objtup[i] for i in perm) => val
            for (objtup, val) in _cls.parameter_values
        ),
        _cls.parameter_defaults
    )
end

"""
    reorder_dimensions!(cls::RelationshipClass, dims::Vector)

Reordering the dimensions of `cls` in-place according to `dims`.

`dims` indicates the new desired order for the dimensions,
and can be either a `Vector{Symbol}` or `Vector{Integer}`.
Note that `dims` needs to correspond to the `object_class_names`
field, not the `intact_object_class_names` field!

Returns the [`RelationshipClass`](@ref) with the reordered dimensions.

See also [`reorderder_dimensions`](@ref).
"""
function reorder_dimensions!(cls::RelationshipClass, dims::Vector)
    reorder_dimensions!(cls.env_dict[_active_env()], dims)
    return cls
end
function reorder_dimensions!(_cls::_RelationshipClass, dims::Vector{Symbol})
    perm = _find_permutation(dims, _cls.object_class_names)
    return reorder_dimensions!(_cls, perm)
end
function reorder_dimensions!(_cls::_RelationshipClass, perm::Vector{<:Integer})
    permute!(_cls.intact_object_class_names, perm)
    permute!(_cls.object_class_names, perm)
    # Reorder relationships list RelationshipLike NamedTuples.
    relkeys = Tuple(_cls.object_class_names)
    for (i, reltup) in enumerate(_cls.relationships)
        _cls.relationships[i] = NamedTuple{relkeys}(reltup)
    end
    # Reorder parameter value dict key ObjectTupleLikes.
    for objtup in collect(keys(_cls.parameter_values))
        _cls.parameter_values[objtup[perm]] = pop!(_cls.parameter_values, objtup)
    end
    # Empty row map and remake split kwargs
    empty!(_cls.row_map)
    _cls._split_kwargs[] = _make_split_kwargs(_cls.object_class_names)
    return _cls
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
