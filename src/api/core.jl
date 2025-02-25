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

"""
    anything

The singleton instance of type [`Anything`](@ref), used to specify *all-pass* filters
in calls to [`EntityClass()`](@ref).
"""
anything = Anything()

"""
    (<ec>::EntityClass)(;<keyword arguments>)

An `Array` of [`Entity`](@ref) tuples corresponding to the [`EntityClass`](@ref) `ec`.

# Arguments

  - For each dimension in `ec` there is a keyword argument named after it.
    The purpose is to filter the result by an entity or list of entities of that class,
    or to accept all entities of that class by specifying `anything` for this argument.
  - `_compact::Bool=true`: whether or not filtered entity classes should be removed from the resulting tuples.
  - `_default=[]`: the default value to return in case no entities pass the filter.

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
function (ec::EntityClass)(; kwargs...)
    byentities = _entity_class_filtering(ec; kwargs...)
    if isempty(ec.subclasses)
        return byentities
    else # Need to filter subclasses as well if they exist.
        return vcat(
            byentities,
            [
                _entity_class_filtering(sc; kwargs...)
                for sc in entity_class.(ec.subclasses)
            ]...
        )
    end
end
function (ec::EntityClass)(name::Symbol) # Old ObjectClass behaviour.
    i = findfirst(e -> e.name == name, ec.entities)
    !isnothing(i) && return ec.entities[i]
    nothing
end
(ec::EntityClass)(name::String) = ec(Symbol(name))

"""
Return a `Vector` of `EntityClass` byentities filtered using given `kwargs`.

See [`EntityClass`](@ref) for documentation on the actual filtering.
"""
function _entity_class_filtering(ec; _compact::Bool=true, _default::Any=[], kwargs...)
    # If kwargs is empty and ec has no dimensions, just return the entities (old ObjectClass behaviour).
    isempty(kwargs) && isempty(ec.dimension_names) && return ec.entities
    # Next, let's check for potential parameter value filters
    class_kwargs, param_kwargs = _split_filter_kwargs(ec, kwargs)
    if !isempty(param_kwargs)
        # Parameter value filters significantly limit the byentities for class filtering.
        byentities = collect(keys(filter(
            byent_param_dict_pair -> _parameter_filter(byent_param_dict_pair, param_kwargs),
            ec.parameter_values
        )))
    else
        # Otherwise include all byentities for class keyword filtering.
        byentities = getproperty.(ec.entities, :byelement_list)
    end
    # Form `RelationshipLike` named tuples and fix name ambiguity.
    byentities = [ # Maybe we could store these in `Entity` upon creation like this already?
        NamedTuple(Pair.(_fix_name_ambiguity(getproperty.(byent, :class_name)), byent))
        for byent in byentities
    ]
    if !isempty(class_kwargs)
        byentities = filter(
            byent -> _byentity_filter(byent, class_kwargs), 
            byentities
        )
        # If _compact, remove filtered dimensions from all byentities
        if _compact
            byentities = map(byent -> _nt_drop(byent, keys(class_kwargs)), byentities)
            # If only a single dimension remains, return the underlying entities
            if all(length.(byentities) .== 1)
                byentities = only.(values.(byentities))
            end
        end
    end
    return isempty(byentities) ? _default : byentities
end

function _split_filter_kwargs(ec::EntityClass, kwargs::Base.Pairs)
    class_kwargs = pairs(_nt_drop((;kwargs...), (keys(ec.parameter_defaults)...,)))
    param_kwargs = pairs(_nt_drop((;kwargs...), keys(class_kwargs)))
    return class_kwargs, param_kwargs
end

function _parameter_filter(
    byent_param_dict_pair::Pair{ObjectTupleLike,Dict{Symbol,ParameterValue}},
    param_kwargs
)
    # Can't do the comparison directly due to `ParameterValue` in byent_param_dict_pair
    param_value_dict = Dict(
        param_name => param_value.value
        for (param_name, param_value) in byent_param_dict_pair.second
    )
    all([_pv_in(kwarg, param_value_dict) for kwarg in param_kwargs])
end

_pv_in(kwarg::Pair{Symbol,Anything}, param_value_dict::Dict) = in(kwarg.first, keys(param_value_dict))
_pv_in(kwarg::Pair, param_value_dict::Dict) = in(kwarg, param_value_dict)

function _byentity_filter(byentity::RelationshipLike, kwargs)
    # Next check that remaining keywords match and are similarly ordered
    byclasses = keys(byentity)
    !isempty(setdiff(keys(kwargs), byclasses)) && return false # Tasku: Filter out if kwargs contains something not in byclasses.
    kw_inds = [findfirst(kw .== byclasses) for (kw, arg) in kwargs]
    !issorted(kw_inds) && return false # Tasku: Filter out unless keywords are in the desired order.
    # Only then do actual argument filtering
    all(_check_byentity_arg(getfield(byentity, kw), arg) for (kw, arg) in kwargs)
end

_check_byentity_arg(ent::Entity, arg::Anything) = true
_check_byentity_arg(ent::Entity, arg::Nothing) = false
_check_byentity_arg(ent::Entity, arg::Symbol) = ent.name == arg
_check_byentity_arg(ent::Entity, arg::ObjectLike) = ent == arg
_check_byentity_arg(ent::Entity, arg::Vector{Entity}) = ent in arg
# The following is a horrible mess dealing with `indices()` output when given as arguments for `_test_indices()`
_check_byentity_arg(ent::Entity, arg::Base.Iterators.Flatten) = _check_byentity_arg(ent, collect(arg))
_check_byentity_arg(ent::Entity, arg::Vector) = ent in only.(values(arg))

"""
    _nt_drop(nt::NamedTuple, keys::Tuple)

Return `nt` with `keys` dropped.
"""
_nt_drop(nt::NamedTuple, keys::Tuple) = Base.structdiff(nt, NamedTuple{(keys...,)})

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
function (pv::ParameterValue)(upd=nothing; kwargs...) end
(pv::ParameterValue{T} where T<:_Scalar)(upd=nothing; kwargs...) = pv.value
(pv::ParameterValue{T} where T<:Array)(upd=nothing; i::Union{Int64,Nothing}=nothing, kwargs...) = _get_value(pv, i)
function (pv::ParameterValue{T} where T<:Union{TimePattern,TimeSeries})(
    upd=nothing; t::Union{DateTime,TimeSlice,Nothing}=nothing, kwargs...
)
    _get_value(pv, t, upd)
end
function (pv::ParameterValue{T} where {T<:Map})(upd=nothing, cycles=0; kwargs...)
    isempty(kwargs) && return _recursive_inner_value(pv.value)
    (kw, arg), new_kwargs = Iterators.peel(kwargs)
    _recursive_inner_value(_get_value(pv, kw, arg, upd, cycles; new_kwargs...))
end
function (pv::ParameterValue{T} where T<:Symbol)(upd=nothing; kwargs...)
    translator = _value_translator()
    translator === nothing && return pv.value
    translated_value = translator(pv.value)
    translated_value === nothing && return pv.value
    parameter_value(translated_value)(upd; kwargs...)
end

_recursive_inner_value(x) = x
_recursive_inner_value(x::ParameterValue) = _recursive_inner_value(x.value)
function _recursive_inner_value(x::Map)
    Map(x.indexes, _recursive_inner_value.(x.values))
end

# Array
_get_value(pv::ParameterValue{T}, ::Nothing) where T<:Array = pv.value
_get_value(pv::ParameterValue{T}, i::Int64) where T<:Array = get(pv.value, i, nothing)
# TimePattern
_get_value(pv::ParameterValue{T}, ::Nothing, upd) where T<:TimePattern = pv.value
function _get_value(pv::ParameterValue{T}, t::DateTime, upd) where T<:TimePattern
    _get_value(pv, TimeSlice(t, t), upd)
end
function _get_value(pv::ParameterValue{T}, t::TimeSlice, upd) where T<:TimePattern
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
        _add_update(t, timeout, upd)
    end
    isempty(vals) && return NaN
    mean(vals)
end
# TimeSeries
_get_value(pv::ParameterValue{T}, ::Nothing, upd) where T<:TimeSeries = pv.value
function _get_value(pv::ParameterValue{T}, t, upd) where T<:TimeSeries
    if pv.value.repeat
        _get_repeating_time_series_value(pv, t, upd)
    else
        _get_time_series_value(pv, t, upd)
    end
end
# Map
function _get_value(pv::ParameterValue{T}, kw, arg, upd, cycles; kwargs...) where {T<:Map}
    i = _search_equal(pv.value.indexes, arg)
    i === nothing && return _get_value_cyclic(pv, kw, arg, upd, cycles; kwargs...)
    pv.value.values[i](upd; kwargs...)
end
function _get_value(pv::ParameterValue{T}, kw, arg::Entity, upd, cycles; kwargs...) where {V,T<:Map{Symbol,V}}
    i = _search_equal(pv.value.indexes, arg.name)
    i === nothing && return _get_value_cyclic(pv, kw, arg, upd, cycles; kwargs...)
    pv.value.values[i](upd; kwargs...)
end
function _get_value(
    pv::ParameterValue{T}, kw, arg::K, upd, cycles; kwargs...
) where {V,K<:Union{DateTime,Float64},T<:Map{K,V}}
    i = _search_nearest(pv.value.indexes, arg)
    i === nothing && return _get_value_cyclic(pv, kw, arg, upd, cycles; kwargs...)
    pv.value.values[i](upd; kwargs...)
end
function _get_value(pv::ParameterValue{T}, kw, arg::Pair{TimeSlice,V}, upd, cycles; kwargs...) where {T<:Map,V}
    t, arg = arg
    if upd !== nothing
        _add_update(t, Minute(-1), upd)
    end
    _get_value(pv, kw, arg, upd, cycles; kwargs...)
end
function _get_value(pv::ParameterValue{T}, kw, arg::Base.RefValue, upd, cycles; kwargs...) where {T<:Map}
    _get_value(pv, kw, arg[], upd, cycles; kwargs...)
end

"""
Called when `arg` is not found at the current level of `pv`.
Push the `kw => arg` to the tail of the `kwargs` and start over.
With this, the order of the `kwargs` doesn't necessarily need to match the order of the `pv` keys.
"""
function _get_value_cyclic(pv::ParameterValue{T}, kw, arg, upd, cycles; kwargs...) where {T<:Map}
    cycles >= length(kwargs) && return pv
    pv(upd, cycles + 1; kwargs..., zip((kw,), (arg,))...)
end

function _get_time_series_value(pv, t::DateTime, upd)
    pv.value.ignore_year && (t -= Year(t))
    t < pv.value.indexes[1] && return NaN
    t > pv.value.indexes[end] && !pv.value.ignore_year && return NaN
    pv.value.values[max(1, searchsortedlast(pv.value.indexes, t))]
end
function _get_time_series_value(pv, t::TimeSlice, upd)
    adjusted_t = pv.value.ignore_year ? t - Year(start(t)) : t
    t_start, t_end = start(adjusted_t), end_(adjusted_t)
    a, b = _search_overlap(pv.value, t_start, t_end)
    if upd !== nothing
        timeout = _timeout(pv.value, t_start, t_end, a, b)
        _add_update(t, timeout, upd)
    end
    t_end <= pv.value.indexes[1] && return NaN
    t_start > pv.value.indexes[end] && !pv.value.ignore_year && return NaN
    mean(Iterators.filter(!isnan, pv.value.values[a:b]))
end

function _get_repeating_time_series_value(pv, t::DateTime, upd)
    pv.value.ignore_year && (t -= Year(t))
    mismatch = t - pv.value.indexes[1]
    reps = fld(mismatch, pv.span)
    t -= reps * pv.span
    pv.value.values[max(1, searchsortedlast(pv.value.indexes, t))]
end
function _get_repeating_time_series_value(pv, t::TimeSlice, upd)
    adjusted_t = pv.value.ignore_year ? t - Year(start(t)) : t
    t_start = start(adjusted_t)
    t_end = end_(adjusted_t)
    mismatch_start = t_start - pv.value.indexes[1]
    mismatch_end = t_end - pv.value.indexes[1]
    reps_start = fld(mismatch_start, pv.span)
    reps_end = fld(mismatch_end, pv.span)
    t_start -= reps_start * pv.span
    t_end -= reps_end * pv.span
    a, b = _search_overlap(pv.value, t_start, t_end)
    if upd !== nothing
        timeout = _timeout(pv.value, t_start, t_end, a, b)
        _add_update(t, timeout, upd)
    end
    reps = reps_end - reps_start
    reps == 0 && return mean(Iterators.filter(!isnan, pv.value.values[a:b]))
    avals = pv.value.values[a:end]
    bvals = pv.value.values[1:b]
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
function indices(p::Parameter, class::EntityClass; kwargs...)
    new_kwargs = (; p.name=>anything, kwargs...)
    (
        ent
        for ent in _entities(class; new_kwargs...)
    )
end

"""
    indices_as_tuples(p::Parameter, [c::Union{ObjectClass,RelationshipClass}]; kwargs...)

Like `indices` but also yields tuples for single-dimensional entities.
"""
function indices_as_tuples(p::Parameter; kwargs...)
    (ent for class in p.classes for ent in indices_as_tuples(p, class; kwargs...))
end
function indices_as_tuples(p::Parameter, class::EntityClass; kwargs...)
    (
        _entity_tuple(ent, class)
        for ent in _entities(class; kwargs...)
        if _get(class.parameter_values[_entity_key(ent)], p.name, class.parameter_defaults)() !== nothing
    )
end

_entities(class::EntityClass; kwargs...) = class(; _compact=false, kwargs...)

_entity_key(o::ObjectLike) = tuple(o)
_entity_key(r::RelationshipLike) = tuple(r...)

_entity_tuple(o::ObjectLike, class) = (; (class.name => o,)...)
_entity_tuple(r::RelationshipLike, class) = r

classes(p::Parameter) = p.classes

push_class!(p::Parameter, class::EntityClass) = push!(p.classes, class)

"""
    add_entities!(entity_class, entities)

Remove from `entities` everything that's already in `entity_class`, and append the rest.
Return the modified `entity_class`.
"""
function add_entities!(entity_class::EntityClass, entities::Vector{Entity})
    setdiff!(entities, entity_class.entities)
    append!(entity_class.entities, entities)
    merge!(entity_class.parameter_values, Dict((ent,) => Dict() for ent in entities))
    entity_class
end
function add_entities!(
    entity_class::EntityClass, entity_tuples::Vector{<:ObjectTupleLike}
)
    new_entities = [
        Entity(
            _default_entity_name_from_tuple(ent_tuple),
            entity_class.name,
            Vector{Entity}(),
            Vector{Entity}(),
            Vector{Entity}([ent_tuple...]),
            vcat(_recursive_byelement_list.([ent_tuple...])...)
        )
        for ent_tuple in entity_tuples
    ]
    new_entities = setdiff(new_entities, entity_class.entities)
    append!(entity_class.entities, new_entities)
    merge!(entity_class.parameter_values, Dict((values(tup) => Dict()) for tup in entity_tuples))
    entity_class
end
function add_entities!(
    entity_class::EntityClass, relationships::Vector{<:RelationshipLike}
)
    add_entities!(entity_class, values.(relationships))
end
# Aliases for backwards compatibility
"""
    add_objects!(object_class, objects)

Remove from `objects` everything that's already in `object_class`, and append the rest.
Return the modified `object_class`.

Alias for [`add_entities!`](@ref) for backwards compatibility.
"""
add_objects!(ec::EntityClass, ents) = add_entities!(ec, ents)
"""
    add_relationships!(relationship_class, relationships)

Remove from `relationships` everything that's already in `relationship_class`, and append the rest.
Return the modified `relationship_class`.

Alias for [`add_entities!`](@ref) for backwards compatibility.
"""
add_relationships!(ec::EntityClass, ents) = add_entities!(ec, ents)

function add_entity!(entity_class::EntityClass, entity::Entity)
    add_entities!(entity_class, [entity])
end
add_object!(ec::EntityClass, o::Entity) = add_entity!(ec, o)
add_relationship!(ec::EntityClass, r::ObjectLike) = add_entity!(ec, r)

function add_parameter_values!(
    entity_class::EntityClass,
    parameter_values::Dict{<:ObjectTupleLike,<:Dict{Symbol,<:ParameterValue}};
    merge_values=false
)
    add_entities!(entity_class, collect(keys(parameter_values)))
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    for (ents, vals) in parameter_values
        do_merge!(entity_class.parameter_values[ents], vals)
    end
end
function add_parameter_values!(
    entity_class::EntityClass,
    parameter_values::Dict{Entity,<:Dict{Symbol,<:ParameterValue}};
    merge_values=false
)
    add_parameter_values!(
        entity_class,
        Dict((key,) => val for (key, val) in parameter_values);
        merge_values=merge_values
    )
end
function add_parameter_values!(
    entity_class::EntityClass,
    parameter_values::Dict{<:RelationshipLike,<:Dict{Symbol,<:ParameterValue}};
    merge_values=false
)
    add_parameter_values!(
        entity_class,
        Dict(values(key) => val for (key, val) in parameter_values);
        merge_values=merge_values
    )
end
# Aliases for backwards compatibility
function add_object_parameter_values!(
    object_class::EntityClass, parameter_values::Dict; merge_values=false
)
    add_parameter_values!(object_class, parameter_values; merge_values=merge_values)
end
function add_relationship_parameter_values!(
    relationship_class::EntityClass, parameter_values::Dict; merge_values=false
)
    add_parameter_values!(relationship_class, parameter_values; merge_values=merge_values)
end

function add_parameter_defaults!(
    entity_class::EntityClass,
    parameter_defaults::Dict{Symbol,<:ParameterValue};
    merge_values=false
)
    do_merge! = merge_values ? mergewith!(merge!) : merge!
    do_merge!(entity_class.parameter_defaults, parameter_defaults)
end
# Aliases for backwards compatibility
function add_object_parameter_defaults!(
    object_class::EntityClass, parameter_defaults::Dict; merge_values=false
)
    add_parameter_defaults!(
        object_class, parameter_defaults; merge_values=merge_values
    )
end
function add_relationship_parameter_defaults!(
    relationship_class::EntityClass, parameter_defaults::Dict; merge_values=false
)
    add_parameter_defaults!(
        relationship_class, parameter_defaults; merge_values=merge_values
    )
end

"""
    entity_classes(m=@__MODULE__)

A sequence of [`EntityClass`](@ref)es generated by [`using_spinedb`](@ref) in the given module.
"""
entity_classes(m=@__MODULE__) = _active_values(m, :_spine_entity_classes)

"""
    parameters(m=@__MODULE__)

A sequence of [`Parameter`](@ref)s generated by [`using_spinedb`](@ref) in the given module.
"""
parameters(m=@__MODULE__) = _active_values(m, :_spine_parameters)

"""
    entity_class(name, m=@__MODULE__)

The [`EntityClass`](@ref) of the given name, generated by [`using_spinedb`](@ref) in the given module.
"""
entity_class(name, m=@__MODULE__) = _active_value(m, :_spine_entity_classes, name)
# Aliases for backwards compatibility
object_class(name, m=@__MODULE__) = entity_class(name, m)
relationship_class(name, m=@__MODULE__) = entity_class(name, m)

"""
    parameter(name, m=@__MODULE__)

The [`Parameter`](@ref) of given name, generated by [`using_spinedb`](@ref) in the given module.
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
        err_msg = "unable to evaluate expression:\n\t$call\n"
        rethrow(ErrorException("$err_msg$(sprint(showerror, e))"))
    end
end

function add_dimension!(cls::EntityClass, name::Symbol, obj)
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

dimensions(cls::EntityClass) = cls.object_class_names

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
