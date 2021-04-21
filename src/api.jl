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

julia> commodity(state_of_matter=:gas)
1-element Array{Object,1}:
 wind
```
"""
function (oc::ObjectClass)(; kwargs...)
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
function (rc::RelationshipClass)(; _compact::Bool=true, _default::Any=[], kwargs...)
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


julia> tax_net_flow(node=:Sthlm, commodity=:water)
4

julia> demand(node=:Sthlm, i=1)
21
```
"""
function (p::Parameter)(; _strict=true, kwargs...)
    pv_new_kwargs = _lookup_parameter_value(p; _strict=_strict, kwargs...)
    if pv_new_kwargs !== nothing
        parameter_value, new_kwargs = pv_new_kwargs
        parameter_value(; new_kwargs...)
    end
end

members(::Anything) = anything
members(x) = unique(member for obj in x for member in obj.members)

groups(x) = unique(group for obj in x for group in obj.groups)

"""
    object_class(m=@__MODULE__)

An `Array` of `ObjectClass`es generated by `using_spinedb` in the given module.
"""
object_class(m=@__MODULE__) = _getproperty_or_default(m, :_spine_object_class, [])

"""
    relationship_class(m=@__MODULE__)

An `Array` of `RelationshipClass`es generated by `using_spinedb` in the given module.
"""
relationship_class(m=@__MODULE__) = _getproperty_or_default(m, :_spine_relationship_class, [])

"""
    parameter(m=@__MODULE__)

An `Array` of `Parameter`s generated by `using_spinedb` in the given module.
"""
parameter(m=@__MODULE__) = _getproperty_or_default(m, :_spine_parameter, [])

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
        ent for class in p.classes for ent in _entities(class; kwargs...) if
        _get(class.parameter_values[_entity_key(ent)], p.name, class.parameter_defaults)() !== nothing
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
iscontained(::Nothing, ::T) where {T} = false

contains(a, b) = iscontained(b, a)
contains(::Nothing, ::T) where {T} = false

"""
    overlaps(a::TimeSlice, b::TimeSlice)

Determine whether `a` and `b` overlap.
"""
overlaps(a::TimeSlice, b::TimeSlice) = start(a) <= start(b) < end_(a) || start(b) <= start(a) < end_(b)
function overlaps(t::TimeSlice, pc::PeriodCollection)
    funcs = Dict{Symbol,Function}(
        :Y => year,
        :M => month,
        :D => day,
        :WD => dayofweek,
        :h => hour,
        :m => minute,
        :s => second,
    )
    for name in fieldnames(PeriodCollection)
        field = getfield(pc, name)
        field === nothing && continue
        func = funcs[name]
        b = func(start(t)):func(end_(t))
        any(!isempty(intersect(a, b)) for a in field) && return true
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
    sort!(t_arr; lt=!iscontained)
    unique!(t_arr)
    f = _IsLowestResolution(t_arr)
    filter!(f, t_arr)
end

"""
    t_highest_resolution!(t_arr)

Remove time slices that contain any other from `t_arr`, and return the modified `t_arr`.
"""
function t_highest_resolution!(t_arr::Array{TimeSlice,1})
    length(t_arr) <= 1 && return t_arr
    sort!(t_arr; lt=!contains)
    unique!(t_arr)
    f = _IsHighestResolution(t_arr)
    filter!(f, t_arr)
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
function add_relationships!(relationship_class::RelationshipClass, relationships::Array{T,1}) where {T}
    setdiff!(relationships, relationship_class.relationships)
    append!(relationship_class.relationships, relationships)
    merge!(relationship_class.parameter_values, Dict(values(rel) => Dict() for rel in relationships))
    if !isempty(relationships)
        empty!(relationship_class.lookup_cache[:true])
        empty!(relationship_class.lookup_cache[:false])
    end
    relationship_class
end

"""
    add_objects!(object_class, objects)

Remove from `objects` everything that's already in `object_class`, and append the rest.
Return the modified `object_class`.
"""
function add_objects!(object_class::ObjectClass, objects::Array{T,1}) where {T}
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
do_realize(x) = x
do_realize(call::IdentityCall) = call.value
do_realize(call::ParameterValueCall) = call.parameter_value(; call.kwargs...)
function do_realize(call::OperatorCall)
    realized_vals = Dict{Int64,Array}()
    st = _OperatorCallTraversalState(call)
    while true
        _visit_node(st)
        _visit_child(st) && continue
        _update_realized_vals!(realized_vals, st)
        _visit_sibling(st) && continue
        _revisit_parent(st) || break
    end
    reduce(call.operator, realized_vals[1])
end

function realize(x)
    try
        do_realize(x)
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
is_varying(call::ParameterValueCall) = true
function is_varying(call::OperatorCall)
    st = _OperatorCallTraversalState(call)
    while true
        st.current isa ParameterValueCall && return true
        _visit_node(st)
        _visit_child(st) && continue
        _visit_sibling(st) && continue
        _revisit_parent(st) || break
    end
    false
end

"""
    update_import_data!(import_data, parameter_name, parameter_value; for_object=true, report="")

Update `import_data` with new data for importing `parameter_name` with value `parameter_value`.
Link the entities to given `report` object.
"""
function update_import_data!(
    import_data::Dict{Symbol,Array},
    parameter_name::Symbol,
    parameter_value::Dict{K,V};
    for_object::Bool=true,
    report::String="",
) where {K<:NamedTuple,V}
    pname = string(parameter_name)
    object_classes = get!(import_data, :object_classes, [])
    object_parameters = get!(import_data, :object_parameters, [])
    objects = get!(import_data, :objects, [])
    object_parameter_values = get!(import_data, :object_parameter_values, [])
    relationship_classes = get!(import_data, :relationship_classes, [])
    relationship_parameters = get!(import_data, :relationship_parameters, [])
    relationships = get!(import_data, :relationships, [])
    relationship_parameter_values = get!(import_data, :relationship_parameter_values, [])
    !isempty(report) && pushfirst!(object_classes, "report")
    for obj_cls_names in unique(keys(key) for key in keys(parameter_value))
        str_obj_cls_names = [string(x) for x in obj_cls_names]
        append!(object_classes, str_obj_cls_names)
        !isempty(report) && pushfirst!(str_obj_cls_names, "report")
        if for_object && length(str_obj_cls_names) == 1
            obj_cls_name = str_obj_cls_names[1]
            push!(object_parameters, (obj_cls_name, pname))
        else
            rel_cls_name = join(str_obj_cls_names, "__")
            push!(relationship_classes, (rel_cls_name, str_obj_cls_names))
            push!(relationship_parameters, (rel_cls_name, pname))
        end
    end
    unique!(object_classes)
    !isempty(report) && pushfirst!(objects, ("report", report))
    for (key, value) in parameter_value
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
            push!(object_parameter_values, (obj_cls_name, obj_name, pname, _unparse_db_value(value)))
        else
            rel_cls_name = join(str_obj_cls_names, "__")
            push!(relationships, (rel_cls_name, str_obj_names))
            push!(relationship_parameter_values, (rel_cls_name, str_obj_names, pname, _unparse_db_value(value)))
        end
    end
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
    parameters::Dict{T,Dict{K,V}},
    url::String;
    upgrade=true,
    create=true,
    for_object=true,
    report="",
    comment="",
) where {T,K<:NamedTuple,V}
    uri = URI(url)
    if uri.scheme == "http"
        write_parameters(parameters, uri; for_object=for_object, report=report, comment=comment)
    else
        _create_db_map(url; upgrade=upgrade, create=create) do db_map
            write_parameters(parameters, db_map; for_object=for_object, report=report, comment=comment)
        end
    end
end
function write_parameters(
    parameters::Dict{T,Dict{K,V}},
    db;
    for_object=true,
    report="",
    comment="",
) where {T,K<:NamedTuple,V}
    import_data = Dict{Symbol,Array}()
    for (parameter_name, parameter_value) in parameters
        update_import_data!(import_data, parameter_name, parameter_value; report=report)
    end
    if isempty(comment)
        comment = string("Add $(join([string(k) for (k, v) in parameters])), automatically from SpineInterface.jl.")
    end
    errors = _import_data(db, import_data, comment)
    isempty(errors) || @warn join([err.msg for err in errors], "\n")
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
    maximum_parameter_value(p::Parameter)

Finds the singe maximum value of a `Parameter` across all its `ObjectClasses` or `RelationshipClasses` in any
`AbstractParameterValue` types.
"""
function maximum_parameter_value(p::Parameter)
    pvs = (first(_lookup_parameter_value(p; ent_tup...)) for class in p.classes for ent_tup in _entity_tuples(class))
    pvs_skip_nothing = (pv for pv in pvs if pv() != nothing)
    isempty(pvs_skip_nothing) && return nothing
    maximum(_maximum_parameter_value(pv) for pv in pvs_skip_nothing)
end

parse_db_value(::Nothing) = nothing
parse_db_value(db_value::String) = _parse_json(JSON.parse(db_value))

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
        :object_parameter_values => [[:oc_name, :obj_name, :param_name, value], ...],
        :relationship_parameter_values => [[:rc_name, [:obj_name1, :obj_name2, ...], :param_name, value], ...],
    )
- `comment::String`: the commit message.

# Example
```
d = Dict(:object_classes => [:dog, :cat], :objects => [[:dog, :brian], [:dog, :spike]])
import_data(url, d, "arf!")
```
"""
function import_data(url::String, data::Dict{String,T}, comment::String) where {T}
    import_data(url, Dict(Symbol(k) => v for (k, v) in data), comment)
end
function import_data(url::String, data::Dict{Symbol,T}, comment::String) where {T}
    uri = URI(url)
    if uri.scheme == "http"
        _import_data(uri, data, comment)
    else
        _create_db_map(url) do db_map
            _import_data(db_map, data, comment)
        end
    end
end
function import_data(url::String, data::Union{ObjectClass,RelationshipClass}, comment::String)
    import_data(url, _to_dict(data), comment)
end