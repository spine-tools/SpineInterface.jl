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
import Dates: CompoundPeriod

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
5-element Array{Object,1}:
 Dublin
 Espoo
 Leuven
 Nimes
 Sthlm

julia> commodity(state_of_matter=commodity(:gas))
1-element Array{Object,1}:
 wind
```
"""
(oc::ObjectClass)(args...; kwargs...) = Base.invokelatest(_call, oc, args...; kwargs...)

function _call(oc::ObjectClass; kwargs...)
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
function _call(oc::ObjectClass, name::Symbol)
    i = findfirst(o -> o.name == name, oc.objects)
    i != nothing && return oc.objects[i]
    nothing
end
_call(oc::ObjectClass, name::String) = oc(Symbol(name))

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
5-element Array{NamedTuple,1}:
 (node = Dublin, commodity = wind)
 (node = Espoo, commodity = wind)
 (node = Leuven, commodity = wind)
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=commodity(:water))
2-element Array{Object,1}:
 Nimes
 Sthlm

julia> node__commodity(node=(node(:Dublin), node(:Espoo)))
1-element Array{Object,1}:
 wind

julia> sort(node__commodity(node=anything))
2-element Array{Object,1}:
 water
 wind

julia> sort(node__commodity(commodity=commodity(:water), _compact=false))
2-element Array{NamedTuple,1}:
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=commodity(:gas), _default=:nogas)
:nogas
```
"""
(rc::RelationshipClass)(args...; kwargs...) = _call(rc, args...; kwargs...)

function _call(rc::RelationshipClass; _compact::Bool=true, _default::Any=[], kwargs...)
    isempty(kwargs) && return rc.relationships
    lookup_key = Tuple(_immutable(get(kwargs, oc, nothing)) for oc in rc.object_class_names)
    relationships = get!(rc.lookup_cache[_compact], lookup_key) do
        cond(rel) = all(rel[rc] in r for (rc, r) in kwargs)
        filtered = filter(cond, rc.relationships)
        if !_compact
            filtered
        else
            object_class_names = setdiff(rc.object_class_names, keys(kwargs))
            if isempty(object_class_names)
                []
            elseif length(object_class_names) == 1
                unique(x[object_class_names[1]] for x in filtered)
            else
                unique(NamedTuple{Tuple(object_class_names)}([x[k] for k in object_class_names]) for x in filtered)
            end
        end
    end
    if !isempty(relationships)
        relationships
    else
        _default
    end
end

"""
    (<p>::Parameter)(;<keyword arguments>)

The value of parameter `p` for a given object or relationship.

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

julia> demand(node=node(:Sthlm), i=1)
21
```
"""
(p::Parameter)(args...; kwargs...) = _call(p, args...; kwargs...)

function _call(p::Parameter; _strict=true, kwargs...)
    pv_new_kwargs = _lookup_parameter_value(p; _strict=_strict, kwargs...)
    if pv_new_kwargs !== nothing
        parameter_value, new_kwargs = pv_new_kwargs
        parameter_value(; new_kwargs...)
    end
end

(p::NothingParameterValue)(; kwargs...) = nothing

(p::ScalarParameterValue)(; kwargs...) = p.value

(p::ArrayParameterValue)(; i::Union{Int64,Nothing}=nothing, kwargs...) = p(i)
(p::ArrayParameterValue)(::Nothing) = p.value
(p::ArrayParameterValue)(i::Int64) = get(p.value, i, nothing)

(p::TimePatternParameterValue)(; t::Union{DateTime,TimeSlice,Nothing}=nothing, kwargs...) = p(t)
(p::TimePatternParameterValue)(::Nothing) = p.value
(p::TimePatternParameterValue)(t::DateTime) = p(TimeSlice(t, t))
function (p::TimePatternParameterValue)(t::TimeSlice)
    vals = [val for (tp, val) in p.value if overlaps(t, tp)]
    isempty(vals) && return nothing
    mean(vals)
end

(p::StandardTimeSeriesParameterValue)(; t::Union{DateTime,TimeSlice,Nothing}=nothing, kwargs...) = p(t)
(p::StandardTimeSeriesParameterValue)(::Nothing) = p.value
function (p::StandardTimeSeriesParameterValue)(t::DateTime)
    p.value.ignore_year && (t -= Year(t))
    p.value.indexes[1] <= t <= p.value.indexes[end] || return nothing
    p.value.values[max(1, searchsortedlast(p.value.indexes, t))]
end
function (p::StandardTimeSeriesParameterValue)(t::TimeSlice)
    p.value.ignore_year && (t -= Year(start(t)))
    ab = _search_overlap(p.value, start(t), end_(t))
    isempty(ab) && return nothing
    a, b = ab
    isempty(a:b) && return nothing
    vals = Iterators.filter(!isnan, p.value.values[a:b])
    mean(vals)
end

(p::RepeatingTimeSeriesParameterValue)(; t::Union{DateTime,TimeSlice,Nothing}=nothing, kwargs...) = p(t)
(p::RepeatingTimeSeriesParameterValue)(::Nothing) = p.value
function (p::RepeatingTimeSeriesParameterValue)(t::DateTime)
    p.value.ignore_year && (t -= Year(t))
    mismatch = t - p.value.indexes[1]
    reps = fld(mismatch, p.span)
    t -= reps * p.span
    p.value.values[max(1, searchsortedlast(p.value.indexes, t))]
end
function (p::RepeatingTimeSeriesParameterValue)(t::TimeSlice)
    t_start = start(t)
    t_end = end_(t)
    p.value.ignore_year && (t_start -= Year(t_start))
    mismatch = t_start - p.value.indexes[1]
    reps = fld(mismatch, p.span)
    t_start -= reps * p.span
    t_end -= reps * p.span
    mismatch = t_end - p.value.indexes[1]
    reps = div(mismatch, p.span)
    ab = _search_overlap(p.value, t_start, t_end - reps * p.span)
    isempty(ab) && return nothing
    a, b = ab
    asum = sum(Iterators.filter(!isnan, p.value.values[a:end]))
    bsum = sum(Iterators.filter(!isnan, p.value.values[1:b]))
    alen = count(!isnan, p.value.values[a:end])
    blen = count(!isnan, p.value.values[1:b])
    (asum + bsum + (reps - 1) * p.valsum) / (alen + blen + (reps - 1) * p.len)
end

function (p::MapParameterValue)(; t=nothing, i=nothing, kwargs...)
    isempty(kwargs) && return p.value
    arg = first(values(kwargs))
    new_kwargs = Base.tail((; kwargs...))
    p(arg; t=t, i=i, new_kwargs...)
end
function (p::MapParameterValue)(k; kwargs...)
    i = _search_equal(p.value.indexes, k)
    i === nothing && return p(; kwargs...)
    pvs = p.value.values[i]
    pvs(; kwargs...)
end
function (p::MapParameterValue{Symbol,V})(o::ObjectLike; kwargs...) where {V}
    i = _search_equal(p.value.indexes, o.name)
    i === nothing && return p(; kwargs...)
    pvs = p.value.values[i]
    pvs(; kwargs...)
end
function (p::MapParameterValue{DateTime,V})(d::DateTime; kwargs...) where {V}
    i = _search_nearest(p.value.indexes, d)
    i === nothing && return p(; kwargs...)
    pvs = p.value.values[i]
    pvs(; kwargs...)
end
function (p::MapParameterValue{DateTime,V})(d::_DateTimeRef; kwargs...) where {V}
    p(d.ref[]; kwargs...)
end

members(::Anything) = anything
members(x) = unique(member for obj in x for member in obj.members)

groups(x) = unique(group for obj in x for group in obj.groups)

"""
    object_classes(m=@__MODULE__)

A sequence of `ObjectClass`es generated by `using_spinedb` in the given module.
"""
object_classes(m=@__MODULE__) = values(_getproperty(m, :_spine_object_classes, Dict()))

"""
    relationship_classes(m=@__MODULE__)

A sequence of `RelationshipClass`es generated by `using_spinedb` in the given module.
"""
relationship_classes(m=@__MODULE__) = values(_getproperty(m, :_spine_relationship_classes, Dict()))

"""
    parameters(m=@__MODULE__)

A sequence of `Parameter`s generated by `using_spinedb` in the given module.
"""
parameters(m=@__MODULE__) = values(_getproperty(m, :_spine_parameters, Dict()))

"""
    object_class(name, m=@__MODULE__)

The `ObjectClass` of given name, generated by `using_spinedb` in the given module.
"""
object_class(name, m=@__MODULE__) = get(_getproperty(m, :_spine_object_classes, Dict()), name, nothing)

"""
    relationship_class(name, m=@__MODULE__)

The `RelationshipClass` of given name, generated by `using_spinedb` in the given module.
"""
relationship_class(name, m=@__MODULE__) = get(_getproperty(m, :_spine_relationship_classes, Dict()), name, nothing)

"""
    parameter(name, m=@__MODULE__)

The `Parameter` of given name, generated by `using_spinedb` in the given module.
"""
parameter(name, m=@__MODULE__) = get(_getproperty(m, :_spine_parameters, Dict()), name, nothing)

"""
    indices(p::Parameter; kwargs...)

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
1-element Array{NamedTuple{(:commodity, :node),Tuple{Object,Object}},1}:
 (commodity = water, node = Sthlm)

julia> collect(indices(demand))
5-element Array{Object,1}:
 Nimes
 Sthlm
 Leuven
 Espoo
 Dublin
```
"""
function indices(p::Parameter; kwargs...)
    (
        ent
        for class in p.classes
        for ent in _entities(class; kwargs...)
        if _get(class.parameter_values[_entity_key(ent)], p.name, class.parameter_defaults)() !== nothing
    )
end

function indices_as_tuples(p::Parameter; kwargs...)
    (
        _entity_tuple(ent, class)
        for class in p.classes
        for ent in _entities(class; kwargs...)
        if _get(class.parameter_values[_entity_key(ent)], p.name, class.parameter_defaults)() !== nothing
    )
end

"""
    duration(t::TimeSlice)

The duration of time slice `t`.
"""
duration(t::TimeSlice) = t.duration

"""
    start(t::TimeSlice)

The start of time slice or time slice map `t` as the referenced `DateTime`.
"""
start(t::TimeSlice) = t.start[]

"""
    startref(t::TimeSlice)

The start of time slice or time slice map `t` as a `_DateTimeRef` value.
"""
startref(t::TimeSlice) = _DateTimeRef(t.start)

"""
    end_(t::TimeSlice)

The end of time slice or time slice map `t`.
"""
end_(t::TimeSlice) = t.end_[]

"""
    blocks(t::TimeSlice)

The temporal blocks where time slice `t` is found.
"""
blocks(t::TimeSlice) = t.blocks

"""
    before(a::TimeSlice, b::TimeSlice)

Determine whether the end point of `a` is exactly the start point of `b`.
"""
before(a::TimeSlice, b::TimeSlice) = start(b) == end_(a)

"""
    iscontained(b, a)

Determine whether `b` is contained in `a`.
"""
iscontained(b::TimeSlice, a::TimeSlice) = start(b) >= start(a) && end_(b) <= end_(a)
iscontained(b::DateTime, a::TimeSlice) = start(a) <= b <= end_(a)

contains(a, b) = iscontained(b, a)

"""
    overlaps(a::TimeSlice, b::TimeSlice)

Determine whether `a` and `b` overlap.
"""
overlaps(a::TimeSlice, b::TimeSlice) = start(a) <= start(b) < end_(a) || start(b) <= start(a) < end_(b)
function overlaps(t::TimeSlice, union::UnionOfIntersections)
    component_enclosing_rounding = Dict(
        :Y => (year, x -> 0, Year),
        :M => (month, year, Month),
        :D => (day, month, Day),
        :WD => (dayofweek, week, Day),
        :h => (hour, day, Hour),
        :m => (minute, hour, Minute),
        :s => (second, minute, Second),
    )
    for intersection in union
        result = true
        for interval in intersection
            component, enclosing, rounding = component_enclosing_rounding[interval.key]
            # Compute component and enclosing component for both start and end of time slice.
            # In the comments below, we assume component is hour, and thus enclosing component is day
            # (but of course, we don't use this assumption in the code itself!)
            t_start, t_end = floor(start(t), rounding), ceil(end_(t), rounding)
            t_lower = component(t_start)
            t_upper = component(t_end)
            t_lower_enclosing = enclosing(t_start)
            t_upper_enclosing = enclosing(t_end)
            if interval.key in (:h, :m, :s)
                # Convert from 0-based to 1-based
                t_lower += 1
                t_upper += 1
            end
            if t_upper_enclosing == t_lower_enclosing
                # Time slice starts and ends on the same day
                # We just need to check whether the time slice and the interval overlap
                if !(interval.lower <= t_lower <= interval.upper || t_lower <= interval.lower < t_upper)
                    result = false
                    break
                end
            elseif t_upper_enclosing == t_lower_enclosing + 1
                # Time slice goes through the day boundary
                # We just need to check that time slice doesn't start after the interval ends on the first day,
                # or ends before the interval starts on the second day
                if t_lower > interval.upper && t_upper <= interval.lower
                    result = false
                    break
                end
                # Time slice spans more than one day
                # Nothing to do, time slice will always contain the interval
            end
        end
        result && return true
    end
    false
end

"""
    overlap_duration(a::TimeSlice, b::TimeSlice)

The duration of the period where `a` and `b` overlap.
"""
function overlap_duration(a::TimeSlice, b::TimeSlice)
    overlaps(a, b) || return 0.0
    overlap_start = max(start(a), start(b))
    overlap_end = min(end_(a), end_(b))
    duration(a) * (Minute(overlap_end - overlap_start) / Minute(end_(a) - start(a)))
end

"""
    roll!(t::TimeSlice, forward::Union{Period,CompoundPeriod})

Roll the given `t` in time by the period specified by `forward`.
"""
function roll!(t::TimeSlice, forward::Union{Period,CompoundPeriod})
    t.start[] += forward
    t.end_[] += forward
    t
end

"""
    t_lowest_resolution!(t_coll)

Remove time slices that are contained in any other from `t_coll`, and return the modified `t_coll`.
"""
t_lowest_resolution!(t_coll::Union{Array{TimeSlice,1},Dict{TimeSlice,T}}) where T = _deleteat!(contains, t_coll)

"""
    t_highest_resolution!(t_coll)

Remove time slices that contain any other from `t_coll`, and return the modified `t_coll`.
"""
t_highest_resolution!(t_coll::Union{Array{TimeSlice,1},Dict{TimeSlice,T}}) where T = _deleteat!(iscontained, t_coll)

"""
    t_highest_resolution(t_iter)

Return an `Array` containing only time slices from `t_iter` that do not contain any other.
"""
t_highest_resolution(t_iter) = t_highest_resolution!(collect(TimeSlice, t_iter))

"""
    t_lowest_resolution(t_iter)

Return an `Array` containing only time slices from `t_iter` that aren't contained in any other.
"""
t_lowest_resolution(t_iter) = t_lowest_resolution!(collect(TimeSlice, t_iter))

"""
    add_relationships!(relationship_class, relationships)

Remove from `relationships` everything that's already in `relationship_class`, and append the rest.
Return the modified `relationship_class`.
"""
function add_relationships!(relationship_class::RelationshipClass, relationships::Array)
    setdiff!(relationships, relationship_class.relationships)
    append!(relationship_class.relationships, relationships)
    merge!(relationship_class.parameter_values, Dict(values(rel) => Dict() for rel in relationships))
    if !isempty(relationships)
        empty!(relationship_class.lookup_cache[:true])
        empty!(relationship_class.lookup_cache[:false])
    end
    relationship_class
end

function add_relationship_parameter_values!(relationship_class::RelationshipClass, parameter_values::Dict)
    add_relationships!(relationship_class, collect(keys(parameter_values)))
    for (rel, vals) in parameter_values
        rel = values(rel)
        merge!(relationship_class.parameter_values[rel], vals)
    end
end

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

function add_object_parameter_values!(object_class::ObjectClass, parameter_values::Dict)
    add_objects!(object_class, collect(keys(parameter_values)))
    for (obj, vals) in parameter_values
        merge!(object_class.parameter_values[obj], vals)
    end
end

"""
    add_object!(object_class, objects)

Append single object to object_class if it doesn't already exist.
Return the modified `object_class`.
"""
function add_object!(object_class::ObjectClass, object::ObjectLike)
    add_objects!(object_class, [object])
end

"""
    realize(x::Call)

Perform the given `Call` and return the result.
"""
function realize(x)
    try
        _do_realize(x)
    catch e
        err_msg = "unable to evaluate expression:\n\t$x\n"
        rethrow(ErrorException("$err_msg$(sprint(showerror, e))"))
    end
end

"""
    is_varying(x::Call)

Whether or not the given `Call` might return a different result if realized a second time.
This is true for `ParameterValueCall`s which are sensitive to the `t` argument.
"""
is_varying(x) = false
is_varying(call::Call) = _is_varying_call(call, call.func)

"""
    update_import_data!(data, parameter_name, value_by_entity; for_object=true, report="", alternative="")

Update `data` with new data for importing `parameter_name` with value `parameter_value`.
Link the entities to given `report` object.
"""
function update_import_data!(
    data::Dict{Symbol,Any},
    parameter_name::T,
    value_by_entity::Dict;
    for_object::Bool=true,
    report::String="",
    alternative::String=""
) where T
    pname = string(parameter_name)
    object_classes = get!(data, :object_classes, [])
    object_parameters = get!(data, :object_parameters, [])
    objects = get!(data, :objects, [])
    object_parameter_values = get!(data, :object_parameter_values, [])
    relationship_classes = get!(data, :relationship_classes, [])
    relationship_parameters = get!(data, :relationship_parameters, [])
    relationships = get!(data, :relationships, [])
    relationship_parameter_values = get!(data, :relationship_parameter_values, [])
    !isempty(report) && pushfirst!(object_classes, "report")
    for obj_cls_names in unique(_object_class_names(entity) for entity in keys(value_by_entity))
        append!(object_classes, obj_cls_names)
        !isempty(report) && pushfirst!(obj_cls_names, "report")
        if for_object && length(obj_cls_names) == 1
            obj_cls_name = obj_cls_names[1]
            push!(object_parameters, (obj_cls_name, pname))
        else
            rel_cls_name = join(obj_cls_names, "__")
            push!(relationship_classes, (rel_cls_name, obj_cls_names))
            push!(relationship_parameters, (rel_cls_name, pname))
        end
    end
    unique!(object_classes)
    !isempty(report) && pushfirst!(objects, ("report", report))
    for (entity, value) in value_by_entity
        obj_cls_names = _object_class_names(entity)
        obj_names = [string(x) for x in values(entity)]
        for (obj_cls_name, obj_name) in zip(obj_cls_names, obj_names)
            push!(objects, (obj_cls_name, obj_name))
        end
        if !isempty(report)
            pushfirst!(obj_cls_names, "report")
            pushfirst!(obj_names, report)
        end
        if for_object && length(obj_cls_names) == length(obj_names) == 1
            obj_cls_name = obj_cls_names[1]
            obj_name = obj_names[1]
            val = [obj_cls_name, obj_name, pname, unparse_db_value(value)]
            !isempty(alternative) && push!(val, alternative)
            push!(object_parameter_values, val)
        else
            rel_cls_name = join(obj_cls_names, "__")
            push!(relationships, (rel_cls_name, obj_names))
            val = [rel_cls_name, obj_names, pname, unparse_db_value(value)]
            !isempty(alternative) && push!(val, alternative)
            push!(relationship_parameter_values, val)
        end
    end
end

"""
    write_parameters(parameters, url::String; <keyword arguments>)

Write `parameters` to the Spine database at the given RFC-1738 `url`.
`parameters` is a dictionary mapping parameter names to another dictionary
mapping object or relationship (`NamedTuple`) to values.

# Arguments

  - `parameters::Dict`: a dictionary mapping parameter names, to entities, to parameter values
  - `upgrade::Bool=true`: whether or not the database at `url` should be upgraded to the latest revision.
  - `for_object::Bool=true`: whether to write an object parameter or a 1D relationship parameter in case the number of
    dimensions is 1.
  - `report::String=""`: the name of a report object that will be added as an extra dimension to the written parameters.
  - `alternative::String`: an alternative to pass to `SpineInterface.write_parameters`.
  - `comment::String=""`: a comment explaining the nature of the writing operation.
"""
function write_parameters(
    parameters::Dict,
    url::String;
    upgrade=true,
    for_object=true,
    report="",
    alternative="",
    on_conflict="merge",
    comment=""
)
    data = Dict{Symbol,Any}(:on_conflict => on_conflict)
    for (parameter_name, value_by_entity) in parameters
        update_import_data!(
            data, parameter_name, value_by_entity; for_object=for_object, report=report, alternative=alternative
        )
    end
    if isempty(comment)
        comment = string("Add $(join([string(k) for (k, v) in parameters])), automatically from SpineInterface.jl.")
    end
    if !isempty(alternative)
        alternatives = get!(data, :alternatives, [])
        push!(alternatives, [alternative])
    end
    count, errors = import_data(url, data, comment; upgrade=upgrade)
    isempty(errors) || @warn join(errors, "\n")
end
function write_parameters(parameter::Parameter, url::String, entities, fn=val->val; kwargs...)
    write_parameters(Dict(parameter.name => Dict(e => fn(parameter(; e...)) for e in entities)), url; kwargs...)
end

"""
    parameter_value(parsed_db_value)

An `AbstractParameterValue` object from the given parsed db value.
"""
parameter_value(::Nothing) = NothingParameterValue()
parameter_value(parsed_db_value::Bool) = ScalarParameterValue(parsed_db_value)
parameter_value(parsed_db_value::Int64) = ScalarParameterValue(parsed_db_value)
parameter_value(parsed_db_value::Float64) = ScalarParameterValue(parsed_db_value)
parameter_value(parsed_db_value::String) = ScalarParameterValue(parsed_db_value)
parameter_value(parsed_db_value::DateTime) = ScalarParameterValue(parsed_db_value)
parameter_value(parsed_db_value::Period) = ScalarParameterValue(parsed_db_value)
parameter_value(parsed_db_value::Array) = ArrayParameterValue(parsed_db_value)
parameter_value(parsed_db_value::TimePattern) = TimePatternParameterValue(parsed_db_value)
parameter_value(parsed_db_value::TimeSeries) = TimeSeriesParameterValue(parsed_db_value)
function parameter_value(parsed_db_value::Map)
    MapParameterValue(Map(parsed_db_value.indexes, parameter_value.(parsed_db_value.values)))
end
parameter_value(parsed_db_value::T) where {T} = error("can't parse $parsed_db_value of unrecognized type $T")

"""
    indexed_parameter_value(indexed_values)

An `AbstractParameterValue` from a dictionary mapping indexes to values.
"""
indexed_parameter_value(indexed_values::Dict{Nothing,V}) where V = parameter_value(indexed_values[nothing])
function indexed_parameter_value(indexed_values::Dict{DateTime,V}) where V
    parameter_value(TimeSeries(collect(keys(indexed_values)), collect(values(indexed_values)), false, false))
end

"""
    indexed_values(value)

An iterator over pairs (index, value) of given value.
In case of non-indexed values, the result only has one element and the index is nothing.
In case of `Map`, the index is a tuple of all the indices leading to a value.
"""
indexed_values(::Nothing) = ((nothing, nothing),)
indexed_values(value) = ((nothing, value),)
indexed_values(value::Array) = enumerate(value)
indexed_values(value::TimePattern) = value
indexed_values(value::TimeSeries) = zip(value.indexes, value.values)
function indexed_values(value::Map)
    (x for (ind, val) in zip(value.indexes, value.values) for x in indexed_values((ind,), val))
end
indexed_values(prefix, value) = (((prefix..., ind), val) for (ind, val) in indexed_values(value))
indexed_values(::NothingParameterValue) = indexed_values(nothing)
indexed_values(pval::AbstractParameterValue) = indexed_values(pval.value)

"""
    maximum_parameter_value(p::Parameter)

Finds the singe maximum value of a `Parameter` across all its `ObjectClasses` or `RelationshipClasses` in any
`AbstractParameterValue` types.
"""
function maximum_parameter_value(p::Parameter)
    pvs = (first(_lookup_parameter_value(p; ent_tup...)) for class in p.classes for ent_tup in _entity_tuples(class))
    pvs_skip_nothing = (pv for pv in pvs if pv() !== nothing)
    isempty(pvs_skip_nothing) && return nothing
    maximum(_maximum_parameter_value(pv) for pv in pvs_skip_nothing)
end

function parse_time_period(union_str::String)
    union_op = ","
    intersection_op = ";"
    range_op = "-"
    union = UnionOfIntersections()
    regexp = r"(Y|M|D|WD|h|m|s)"
    for intersection_str in split(union_str, union_op)
        intersection = IntersectionOfIntervals()
        for interval in split(intersection_str, intersection_op)
            m = Base.match(regexp, interval)
            m === nothing && error("invalid interval specification $interval.")
            key = m.match
            lower_upper = interval[(length(key) + 1):end]
            lower_upper = split(lower_upper, range_op)
            length(lower_upper) != 2 && error("invalid interval specification $interval.")
            lower_str, upper_str = lower_upper
            lower = try
                parse(Int64, lower_str)
            catch ArgumentError
                error("invalid lower bound $lower_str.")
            end
            upper = try
                parse(Int64, upper_str)
            catch ArgumentError
                error("invalid upper bound $upper_str.")
            end
            lower > upper && error("lower bound can't be higher than upper bound.")
            push!(intersection, TimeInterval(Symbol(key), lower, upper))
        end
        push!(union, intersection)
    end
    union
end

parse_db_value(value_and_type::Vector{Any}) = parse_db_value(value_and_type...)
function parse_db_value(value::Vector{UInt8}, type::Union{String,Nothing})
    isempty(value) && return nothing
    _parse_db_value(JSON.parse(String(value)), type)
end
parse_db_value(::Nothing, type) = nothing
parse_db_value(x) = _parse_db_value(x)

unparse_db_value(x) = Vector{UInt8}(_serialize_pv(db_value(x))), _db_type(x)
unparse_db_value(x::AbstractParameterValue) = unparse_db_value(x.value)
unparse_db_value(::NothingParameterValue) = unparse_db_value(nothing)

db_value(x) = x
db_value(x::Dict) = Dict(k => v for (k, v) in x if k != "type")
db_value(x::DateTime) = Dict("data" => string(Dates.format(x, db_df)))
db_value(x::T) where {T<:Period} = Dict("data" => _unparse_duration(x))
function db_value(x::Array{T}) where {T}
    Dict{String,Any}("value_type" => _inner_type_str(T), "data" => _unparse_element.(x))
end
function db_value(x::TimePattern)
    Dict{String,Any}("data" => Dict(_unparse_time_pattern(k) => v for (k, v) in x))
end
function db_value(x::TimeSeries)
    Dict{String,Any}(
        "index" => Dict("repeat" => x.repeat, "ignore_year" => x.ignore_year),
        "data" => OrderedDict(_unparse_date_time(i) => v for (i, v) in zip(x.indexes, x.values)),
    )
end
function db_value(x::Map{K,V}) where {K,V}
    Dict{String,Any}(
        "index_type" => _inner_type_str(K),
        "data" => [(i, _unparse_map_value(v)) for (i, v) in zip(x.indexes, x.values)],
    )
end


"""
    import_data(url, data, comment)

Import data to a Spine db.

# Arguments
- `url::String`: the url of the target database. 
- `data::Dict`: the data to import, in the format below:
    Dict(
        :object_classes => [:oc_name, ...],
        :relationship_classes => [[:rc_name, [:oc_name1, :oc_name2, ...]], ...],
        :objects => [[:oc_name, :obj_name], ...],
        :relationships => [[:rc_name, [:obj_name1, :obj_name2, ...], ...],
        :object_parameters => [[:oc_name, :param_name, default_value], ...],
        :relationship_parameters => [[:rc_name, :param_name, default_value], ...],
        :object_parameter_values => [[:oc_name, :obj_name, :param_name, value, :alt_name], ...],
        :relationship_parameter_values => [[:rc_name, [:obj_name1, :obj_name2, ...], :param_name, value, :alt_name], ...],
        :object_groups => [[:class_name, :group_name, :member_name], ...],
        :scenarios => [(:scen_name, true), ...],  # true for the active flag, not in use at the moment
        :alternatives => [:alt_name, ...],
        :scenario_alternatives => [(:scen_name, :alt_name, nothing), (:scen_name, :lower_alt_name, :alt_name), ...]
    )
- `comment::String`: the commit message.

# Example
```
d = Dict(:object_classes => [:dog, :cat], :objects => [[:dog, :brian], [:dog, :spike]])
import_data(url, d, "arf!")
```
"""
function import_data(url::String, data::Union{ObjectClass,RelationshipClass}, comment::String; upgrade=false)
    import_data(url, _to_dict(data), comment; upgrade=upgrade)
end
function import_data(url::String, data::Vector, comment::String; upgrade=false)
    import_data(url, merge(append!, _to_dict.(data)...), comment; upgrade=upgrade)
end
function import_data(url::String, data::Dict{String,T}, comment::String; upgrade=false) where {T}
    import_data(url, Dict(Symbol(k) => v for (k, v) in data), comment; upgrade=upgrade)
end
function import_data(url::String, comment::String; upgrade=false, kwargs...)
    import_data(url, Dict(Symbol(k) => v for (k, v) in pairs(kwargs)), comment; upgrade=upgrade)
end
function import_data(url::String, data::Dict{Symbol,T}, comment::String; upgrade=false) where {T}
    _db(url; upgrade=upgrade) do db
        _import_data(db, data, comment)
    end
end

"""
    run_request(url::String, request::String, args, kwargs; upgrade=false)

Run the given request on the given url, using the given args.
"""
function run_request(url::String, request::String; upgrade=false)
    run_request(url, request, (), Dict(); upgrade=upgrade)
end
function run_request(url::String, request::String, args::Tuple; upgrade=false)
    run_request(url, request, args, Dict(); upgrade=upgrade)
end
function run_request(url::String, request::String, kwargs::Dict; upgrade=false)
    run_request(url, request, (), kwargs; upgrade=upgrade)
end
function run_request(url::String, request::String, args::Tuple, kwargs::Dict; upgrade=false)
    _db(url; upgrade=upgrade) do db
        _run_request(db, request, args, kwargs)
    end
end

"""
    timedata_operation(f::Function, x)

Perform `f` element-wise for potentially `TimeSeries` or `TimePattern` argument `x`.
"""
timedata_operation(f::Function, x::TimeSeries) = TimeSeries(x.indexes, f.(x.values), x.ignore_year, x.repeat)
timedata_operation(f::Function, x::TimePattern) = Dict(key => f(val) for (key, val) in x)
timedata_operation(f::Function, x::Number) = f(x)

"""
    timedata_operation(f::Function, x, y)

Perform `f` element-wise for potentially `TimeSeries` or `TimePattern` arguments `x` and `y`.

Operations between `TimeSeries`/`TimePattern` and `Number` are supported.
If both `x` and `y` are either `TimeSeries` or `TimePattern`, the timestamps of `x` and `y` are combined,
and both time-dependent data are sampled on each timestamps to perform the desired operation.
If either `ts1` or `ts2` are `TimeSeries`, returns a `TimeSeries`.
If either `ts1` or `ts2` has the `ignore_year` or `repeat` flags set to `true`, so does the resulting `TimeSeries`.

Operations between two `TimePattern`s are currently supported only if they have the exact same keys.
"""
timedata_operation(f::Function, x::TimeSeries, y::Number) = TimeSeries(
    x.indexes, f.(x.values, y), x.ignore_year, x.repeat
)
timedata_operation(f::Function, y::Number, x::TimeSeries) = TimeSeries(
    x.indexes, f.(y, x.values), x.ignore_year, x.repeat
)
timedata_operation(f::Function, x::TimePattern, y::Number) = Dict(key => f(val, y) for (key, val) in x)
timedata_operation(f::Function, y::Number, x::TimePattern) = Dict(key => f(y, val) for (key, val) in x)
function timedata_operation(f::Function, x::TimeSeries, y::TimeSeries)
    indexes, values = if x.indexes == y.indexes && !x.ignore_year && !y.ignore_year && !x.repeat && !y.repeat
        x.indexes, broadcast(f, x.values, y.values)
    else
        _timedata_operation(f, x, y)
    end
    ignore_year = x.ignore_year && y.ignore_year
    repeat = x.repeat && y.repeat
    TimeSeries(indexes, values, ignore_year, repeat)
end
function timedata_operation(f::Function, x::TimeSeries, y::TimePattern)
    indexes, values = _timedata_operation(f, x, y)
    TimeSeries(indexes, values, x.ignore_year, x.repeat)
end
function timedata_operation(f::Function, x::TimePattern, y::TimeSeries)
    indexes, values = _timedata_operation(f, x, y)
    TimeSeries(indexes, values, y.ignore_year, y.repeat)
end
function timedata_operation(f::Function, x::TimePattern, y::TimePattern)
    if keys(x) == keys(y)
        Dict(key => f(x[key], y[key]) for key in keys(x))
    else
        @error "`TimePattern-TimePattern` arithmetic currently only supported if the keys are identical!"
    end
end

"""
    difference(left, right)

A string sumarizing spine values (ObjectClass, RelationshipClass, Parameter) from module `left`
that are absent from module `right`.
"""
function difference(left, right)
    _name(x) = x.name
    diff = OrderedDict(
        "object classes" => setdiff(_name.(object_classes(left)), _name.(object_classes(right))),
        "relationship classes" => setdiff(_name.(relationship_classes(left)), _name.(relationship_classes(right))),
        "parameters" => setdiff(_name.(parameters(left)), _name.(parameters(right))),
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

function map_to_time_series(
    map::Map{K,V}, range=nothing
) where {K,V<:Union{TimeSeries,AbstractTimeSeriesParameterValue}}
    inds = []
    vals = []
    for ts in _inner_value.(values(map))
        append!(inds, _get_range(ts.indexes, range))
        append!(vals, _get_range(ts.values, range))
    end
    TimeSeries(inds, vals, false, false)
end

function open_connection(db_url)
    _handlers[db_url] = _create_db_handler(db_url, false)
end

function close_connection(db_url)
    handler = pop!(_handlers, db_url, nothing)
    handler === nothing || _close_db_handler(handler)
end

