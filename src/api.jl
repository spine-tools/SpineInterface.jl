#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of Spine Model.
#
# Spine Model is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# Spine Model is distributed in the hope that it will be useful,
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

julia> commodity(state_of_matter=:gas)
1-element Array{Object,1}:
 wind

```
"""
function (oc::ObjectClass)(;kwargs...)
    isempty(kwargs) && return oc.objects
    function cond(o)
        for (p, v) in kwargs
            value = get(oc.parameter_values[o], p, nothing)
            (value !== nothing && value() === v) || return false
        end
        true
    end
    filter(cond, oc.objects)
end
function (oc::ObjectClass)(name::Symbol)
    i = findfirst(o -> o.name == name, oc.objects)
    i != nothing && return oc.objects[i]
    nothing
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
5-element Array{NamedTuple,1}:
 (node = Dublin, commodity = wind)
 (node = Espoo, commodity = wind)
 (node = Leuven, commodity = wind)
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=:water)
2-element Array{Object,1}:
 Nimes
 Sthlm

julia> node__commodity(node=(:Dublin, :Espoo))
1-element Array{Object,1}:
 wind

julia> sort(node__commodity(node=anything))
2-element Array{Object,1}:
 water
 wind

julia> sort(node__commodity(commodity=:water, _compact=false))
2-element Array{NamedTuple,1}:
 (node = Nimes, commodity = water)
 (node = Sthlm, commodity = water)

julia> node__commodity(commodity=:gas, _default=:nogas)
:nogas

```
"""
function (rc::RelationshipClass)(;_compact::Bool=true, _default::Any=[], kwargs...)
    isempty(kwargs) && return rc.relationships
    lookup_key = Tuple(_immutable(get(kwargs, oc, anything)) for oc in rc.object_class_names)
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
- `_strict::Bool`: whether to raise an error or return `nothing` if the parameter is not specified for the given arguments.


# Examples

```jldoctest
julia> using SpineInterface;

julia> url = "sqlite:///" * joinpath(dirname(pathof(SpineInterface)), "..", "examples/data/example.sqlite");

julia> using_spinedb(url)

julia> tax_net_flow(node=:Sthlm, commodity=:water)
4

julia> demand(node=:Sthlm, i=1)
21

```
"""
function (p::Parameter)(;i=nothing, t=nothing, _strict=true, kwargs...)
    parameter_value = _lookup_parameter_value(p; kwargs...)
    parameter_value != nothing && return parameter_value(i=i, t=t)
    _strict && error("parameter $p is not specified for argument(s) $(kwargs...)")
    nothing
end

"""
    (<m>::TimeSliceMap)(t::TimeSlice...)

An `Array` of `TimeSlice`s in the map that match the given `t`.
"""
function (m::TimeSliceMap)(t::TimeSlice...)
    from_to_minutes = (
        _from_to_minute(m.start, s_start, s_end)
        for (s_start, s_end) in ((max(m.start, start(s)), min(m.end_, end_(s))) for s in t)
        if s_start < s_end
    )
    unique(
        m.time_slices[ind]
        for (from_minute, to_minute) in from_to_minutes
        for ind in m.index[from_minute]:m.index[to_minute]
    )
end

"""
    object_class(m=@__MODULE__)

An `Array` of `ObjectClass`es generated by `using_spinedb` in the given module.
"""
object_class(m=@__MODULE__) = _getproperty_or_default(m, :_spine_object_class)

"""
    relationship_class(m=@__MODULE__)

An `Array` of `RelationshipClass`es generated by `using_spinedb` in the given module.
"""
relationship_class(m=@__MODULE__) = _getproperty_or_default(m, :_spine_relationship_class)

"""
    parameter(m=@__MODULE__)

An `Array` of `Parameter`s generated by `using_spinedb` in the given module.
"""
parameter(m=@__MODULE__) = _getproperty_or_default(m, :_spine_parameter)

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
        for ent in _lookup_entities(class; kwargs...)
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

The start of time slice `t`.
"""
start(t::TimeSlice) = t.start[]

"""
    end_(t::TimeSlice)

The end of time slice `t`.
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
iscontained(b::UnitRange{Int64}, a::UnitRange{Int64}) = b.start >= a.start && b.stop <= a.stop
function iscontained(ts::TimeSlice, pc::PeriodCollection)
    fdict = Dict{Symbol,Function}(
        :Y => year,
        :M => month,
        :D => day,
        :WD => dayofweek,
        :h => hour,
        :m => minute,
        :s => second,
    )
    conds = Array{Bool,1}()
    sizehint!(conds, 7)
    for name in fieldnames(PeriodCollection)
        getfield(pc, name) == nothing && continue
        f = fdict[name]
        b = f(start(ts)):f(end_(ts))
        push!(conds, any(iscontained(b, a) for a in getfield(pc, name)))
    end
    all(conds)
end

"""
    overlaps(a::TimeSlice, b::TimeSlice)

Determine whether `a` and `b` overlap.
"""
overlaps(a::TimeSlice, b::TimeSlice) = start(a) <= start(b) < end_(a) || start(b) <= start(a) < end_(b)

"""
    overlap_duration(a::TimeSlice, b::TimeSlice)

The duration of the period where `a` and `b` overlap.
"""
function overlap_duration(a::TimeSlice, b::TimeSlice)
    overlaps(a, b) || return 0.0
    overlap_start = max(start(a), start(b))
    overlap_end = min(end_(a), end_(b))
    duration(a) * Minute(overlap_end - overlap_start) / Minute(end_(a) - start(a))
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
    t_lowest_resolution!(t_arr::Array{TimeSlice,1})

Remove time slices that are contained in any other from `t_arr`, and return the modified `t_arr`.
"""
function t_lowest_resolution!(t_arr::Array{TimeSlice,1})
    length(t_arr) <= 1 && return t_arr
    sort!(t_arr)
    unique!(t_arr)
    inds_to_drop = (k for (k, (t1, t2)) in enumerate(zip(t_arr[1:end - 1], t_arr[2:end])) if iscontained(t1, t2))
    deleteat!(t_arr, inds_to_drop)
end

"""
    t_highest_resolution!(t_arr)

Remove time slices that contain any other from `t_arr`, and return the modified `t_arr`.
"""
function t_highest_resolution!(t_arr::Array{TimeSlice,1})
    length(t_arr) <= 1 && return t_arr
    sort!(t_arr)
    unique!(t_arr)
    inds_to_drop = (k + 1 for (k, (t1, t2)) in enumerate(zip(t_arr[1:end - 1], t_arr[2:end])) if iscontained(t1, t2))
    deleteat!(t_arr, inds_to_drop)
end

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
function add_relationships!(relationship_class::RelationshipClass, relationships::Array{T,1}) where T<:RelationshipLike
    setdiff!(relationships, relationship_class.relationships)
    append!(relationship_class.relationships, relationships)
    merge!(relationship_class.parameter_values, Dict(values(rel) => Dict() for rel in relationships))
    isempty(relationships) || empty!(relationship_class.lookup_cache)
    relationship_class
end

"""
    add_objects!(object_class, objects)

Remove from `objects` everything that's already in `object_class`, and append the rest.
Return the modified `object_class`.
"""
function add_objects!(object_class::ObjectClass, objects::Array{T,1}) where T<:ObjectLike
    setdiff!(objects, object_class.objects)
    append!(object_class.objects, objects)
    merge!(object_class.parameter_values, Dict(obj => Dict() for obj in objects))
    object_class
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
realize(x) = x
realize(call::IdentityCall) = call.value
realize(call::OperatorCall) = call.operator(realize.(call.args)...)
realize(call::ParameterCall) = call.parameter(; call.kwargs...)

"""
    is_varying(x::Call)

Whether or not the given `Call` might return a different result if realized a second time.
This is true for `ParameterCall`s which are sensitive to the `t` argument.
"""
is_varying(x) = false
is_varying(call::OperatorCall) = any(is_varying(arg) for arg in call.args)
is_varying(call::ParameterCall) = true

"""
    write_parameter!(db_map, name, data; for_object=true, report="")

Create parameter in `db_map`, with given `name` and `data`.
Link the parameter to given `report` object.
"""
function write_parameter!(
        db_map::PyObject,
        name,
        data::Dict{K,V};
        for_object::Bool=true,
        report::String="") where {K<:NamedTuple,V}
    object_classes = []
    object_parameters = []
    objects = []
    object_parameter_values = []
    relationship_classes = []
    relationship_parameters = []
    relationships = []
    relationship_parameter_values = []
    !isempty(report) && pushfirst!(object_classes, "report")
    for obj_cls_names in unique(keys(key) for key in keys(data))
        str_obj_cls_names = [string(x) for x in obj_cls_names]
        append!(object_classes, str_obj_cls_names)
        !isempty(report) && pushfirst!(str_obj_cls_names, "report")
        if for_object && length(str_obj_cls_names) == 1
            obj_cls_name = str_obj_cls_names[1]
            push!(object_parameters, (obj_cls_name, string(name)))
        else
            rel_cls_name = join(str_obj_cls_names, "__")
            push!(relationship_classes, (rel_cls_name, str_obj_cls_names))
            push!(relationship_parameters, (rel_cls_name, string(name)))
        end
    end
    unique!(object_classes)
    !isempty(report) && pushfirst!(objects, ("report", report))
    for (key, value) in data
        str_obj_cls_names = [string(x) for x in keys(key)]
        str_obj_names = [string(x) for x in values(key)]
        for (obj_cls_name, obj_name) in zip(str_obj_cls_names, str_obj_names)
            push!(objects, (obj_cls_name, obj_name))
        end
        if !isempty(report)
            pushfirst!(str_obj_cls_names, "report")
            pushfirst!(str_obj_names, report)
        end
        if for_object && length(str_obj_cls_names) == length(str_obj_names) == 1
            obj_cls_name = str_obj_cls_names[1]
            obj_name = str_obj_names[1]
            push!(object_parameter_values, (obj_cls_name, obj_name, string(name), value))
        else
            rel_cls_name = join(str_obj_cls_names, "__")
            push!(relationships, (rel_cls_name, str_obj_names))
            push!(relationship_parameter_values, (rel_cls_name, str_obj_names, string(name), value))
        end
    end
    added, err_log = db_api.import_data(
        db_map,
        object_classes=object_classes,
        relationship_classes=relationship_classes,
        object_parameters=object_parameters,
        relationship_parameters=relationship_parameters,
        objects=objects,
        relationships=relationships,
        object_parameter_values=object_parameter_values,
        relationship_parameter_values=relationship_parameter_values,
    )
    isempty(err_log) || @warn join([x.msg for x in err_log], "\n")
    added
end

"""
    write_parameters(parameters, url::String; <keyword arguments>)

Write `parameters` to the Spine database at the given RFC-1738 `url`.
`parameters` is a dictionary mapping parameter names to another dictionary
mapping object or relationship (`NamedTuple`) to values.

# Arguments

- `upgrade::Bool=true`: whether or not the database at `url` should be upgraded to the latest revision.
- `for_object::Bool=true`: whether to write an object parameter or a 1D relationship parameter in case the number of
    dimensions is 1.
- `report::String=""`: the name of a report object that will be added as an extra dimension to the written parameters.
- `comment::String=""`: a comment explaining the nature of the writing operation.
- `<parameters>`: a dictionary mapping
"""
function write_parameters(
        parameters::Dict{T,Dict{K,V}}, dest_url::String; upgrade=false, for_object=true, report="", comment=""
    ) where {T,K<:NamedTuple,V}
    db_map = try
        DiffDatabaseMapping(dest_url; upgrade=upgrade)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBAPIError)
            db_api.create_new_spine_database(dest_url)
            DiffDatabaseMapping(dest_url; upgrade=upgrade)
        else
            rethrow()
        end
    end
    write_parameters(parameters, db_map; for_object=for_object, report=report, comment=comment)
end
function write_parameters(
        parameters::Dict{T,Dict{K,V}}, db_map::PyObject; for_object=true, report="", comment=""
    ) where {T,K<:NamedTuple,V}
    added = 0
    for (name, data) in parameters
        added += write_parameter!(db_map, name, data; report=report)
    end
    added == 0 && return
    if isempty(comment)
        comment = string("Add $(join([string(k) for (k, v) in parameters])), automatically from SpineInterface.jl.")
    end
    try
        db_map.commit_session(comment)
    catch err
        db_map.rollback_session()
        rethrow()
    end
end

"""A DatabaseMapping object using Python spinedb_api"""
function DiffDatabaseMapping(db_url::String; upgrade=false)
    try
        db_api.DiffDatabaseMapping(db_url, upgrade=upgrade)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBVersionError)
            error(
                """
                The database at '$db_url' is from an older version of Spine
                and needs to be upgraded in order to be used with the current version.

                You can upgrade it by running `using_spinedb(db_url; upgrade=true)`.

                WARNING: After the upgrade, the database may no longer be used
                with previous versions of Spine.
                """
            )
        else
            rethrow()
        end
    end
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
parameter_value(parsed_db_value::Array) = ArrayParameterValue(parsed_db_value)
parameter_value(parsed_db_value::DateTime_) = ScalarParameterValue(parsed_db_value.value)
parameter_value(parsed_db_value::ScalarDuration) = ScalarParameterValue(parsed_db_value.value)
parameter_value(parsed_db_value::ArrayDuration) = ArrayParameterValue(parsed_db_value.value)
parameter_value(parsed_db_value::Array_) = ArrayParameterValue(parsed_db_value.value)
parameter_value(parsed_db_value::TimePattern) = TimePatternParameterValue(parsed_db_value)
parameter_value(parsed_db_value::TimeSeries) = TimeSeriesParameterValue(parsed_db_value)