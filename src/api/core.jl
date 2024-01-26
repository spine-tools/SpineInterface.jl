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
function (oc::ObjectClass)(; kwargs...)
    cols = [oc.name]
    isempty(kwargs) && return EntityFrame(@view oc.entities[:, cols])
    f = row -> all(_default_if_missing(row, oc, p_name)() == val for (p_name, val) in kwargs)
    rows = f.(eachrow(oc.entities))
    EntityFrame(@view oc.entities[rows, cols])
end
function (oc::ObjectClass)(name::Symbol)
    objects = filter(oc.name => obj -> obj.name == name, oc.entities)[!, oc.name]
    isempty(objects) && return nothing
    first(objects)
end
(oc::ObjectClass)(name::String) = oc(Symbol(name))

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
function (rc::RelationshipClass)(; _compact::Bool=true, _default::Any=nothing, kwargs...)
    cols = _object_class_names(rc)
    if _default === nothing
        _default = EntityFrame(empty(rc.entities[:, cols]))
    end
    isempty(kwargs) && return EntityFrame(@view rc.entities[:, cols])
    _compact && setdiff!(cols, keys(kwargs))
    isempty(cols) && return _default
    entity = Tuple(get(kwargs, n, anything) for n in _object_class_names(rc))
    rows = _find_rows(rc, entity)
    rows == (:) && return EntityFrame(@view rc.entities[:, cols])
    isempty(rows) && return _default
    rows = sort!(collect(values(Dict(NamedTuple(rc.entities[row, cols]) => row for row in rows))))
    EntityFrame(@view rc.entities[rows, cols])
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

julia> demand(node=node(:Sthlm), i=1)
21
```
"""
function (p::Parameter)(; _strict=true, _default=nothing, kwargs...)
    pv_new_kwargs = _split_parameter_value_kwargs(p; _strict=_strict, _default=_default, kwargs...)
    if pv_new_kwargs !== nothing
        pv, new_kwargs = pv_new_kwargs
        pv(; new_kwargs...)
    else
        _default
    end
end

"""
    (<pv>::ParameterValue)(callback; <keyword arguments>)

A value from `pv`.
"""
function (pv::ParameterValue)(callback=nothing; kwargs...) end

(pv::ParameterValue{T} where T<:_Scalar)(callback=nothing; kwargs...) = pv.value
(pv::ParameterValue{T} where T<:Array)(callback=nothing; i::Union{Int64,Nothing}=nothing, kwargs...) = _get_value(pv, i)
function (pv::ParameterValue{T} where T<:TimePattern)(
    callback=nothing; t::Union{DateTime,TimeSlice,Nothing}=nothing, kwargs...
)
    _get_value(pv, t, callback)
end
function (pv::ParameterValue{T} where T<:TimeSeries)(
    callback=nothing; t::Union{DateTime,TimeSlice,Nothing}=nothing, kwargs...
)
    _get_value(pv, t, callback)
end
function (pv::ParameterValue{T} where {T<:Map})(callback=nothing; t=nothing, i=nothing, kwargs...)
    isempty(kwargs) && return _recursive_inner_value(pv.value)
    arg = first(values(kwargs))
    new_kwargs = Base.tail((; kwargs...))
    _recursive_inner_value(_get_value(pv, arg, callback; t=t, i=i, new_kwargs...))
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
_get_value(pv::ParameterValue{T}, ::Nothing, callback) where T<:TimePattern = pv.value
function _get_value(pv::ParameterValue{T}, t::DateTime, callback) where T<:TimePattern
    _get_value(pv, TimeSlice(t, t), callback)
end
function _get_value(pv::ParameterValue{T}, t::TimeSlice, callback) where T<:TimePattern
    vals = [val for (tp, val) in pv.value if overlaps(t, tp)]
    if callback !== nothing
        timeout = if isempty(vals)
            Second(0)
        else
            min(
                floor(start(t), pv.precision) + pv.precision(1) - start(t),
                ceil(end_(t), pv.precision) + Millisecond(1) - end_(t)
            )
        end
        _add_callback(t, timeout, callback)
    end
    isempty(vals) && return NaN
    mean(vals)
end
# TimeSeries
_get_value(pv::ParameterValue{T}, ::Nothing, callback) where T<:TimeSeries = pv.value
function _get_value(pv::ParameterValue{T}, t, callback) where T<:TimeSeries
    if pv.value.repeat
        _get_repeating_time_series_value(pv, t, callback)
    else
        _get_time_series_value(pv, t, callback)
    end
end
function _get_time_series_value(pv, t::DateTime, callback)
    pv.value.ignore_year && (t -= Year(t))
    t < pv.value.indexes[1] && return NaN
    t > pv.value.indexes[end] && !pv.value.ignore_year && return NaN
    pv.value.values[max(1, searchsortedlast(pv.value.indexes, t))]
end
function _get_time_series_value(pv, t::TimeSlice, callback)
    adjusted_t = pv.value.ignore_year ? t - Year(start(t)) : t
    t_start, t_end = start(adjusted_t), end_(adjusted_t)
    a, b = _search_overlap(pv.value, t_start, t_end)
    if callback !== nothing
        timeout = _timeout(pv.value, t_start, t_end, a, b)
        _add_callback(t, timeout, callback)
    end
    t_end <= pv.value.indexes[1] && return NaN
    t_start > pv.value.indexes[end] && !pv.value.ignore_year && return NaN
    mean(Iterators.filter(!isnan, pv.value.values[a:b]))
end
function _get_repeating_time_series_value(pv, t::DateTime, callback)
    pv.value.ignore_year && (t -= Year(t))
    mismatch = t - pv.value.indexes[1]
    reps = fld(mismatch, pv.span)
    t -= reps * pv.span
    pv.value.values[max(1, searchsortedlast(pv.value.indexes, t))]
end
function _get_repeating_time_series_value(pv, t::TimeSlice, callback)
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
    if callback !== nothing
        timeout = _timeout(pv.value, t_start, t_end, a, b)
        _add_callback(t, timeout, callback)
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
# Map
function _get_value(pv::ParameterValue{T}, k, callback; kwargs...) where {T<:Map}
    i = _search_equal(pv.value.indexes, k)
    i === nothing && return pv(callback; kwargs...)
    pv.value.values[i](callback; kwargs...)
end
function _get_value(pv::ParameterValue{T}, o::ObjectLike, callback; kwargs...) where {V,T<:Map{Symbol,V}}
    i = _search_equal(pv.value.indexes, o.name)
    i === nothing && return pv(callback; kwargs...)
    pv.value.values[i](callback; kwargs...)
end
function _get_value(pv::ParameterValue{T}, d::DateTime, callback; kwargs...) where {V,T<:Map{DateTime,V}}
    i = _search_nearest(pv.value.indexes, d)
    i === nothing && return pv(callback; kwargs...)
    pv.value.values[i](callback; kwargs...)
end
function _get_value(pv::ParameterValue{T}, s::_StartRef, callback; kwargs...) where {V,T<:Map{DateTime,V}}
    t = s.time_slice
    i = _search_nearest(pv.value.indexes, start(t))
    if callback !== nothing
        timeout = i === nothing ? Second(0) : _next_index(pv.value, i) - start(t)
        _add_callback(s.time_slice, timeout, callback)
    end
    i === nothing && return pv(callback; kwargs...)
    pv.value.values[i](callback; kwargs...)
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
    i > 0 && return i
    nothing
end
_search_nearest(arr, x) = nothing

_next_index(val::Union{TimeSeries,Map}, pos) = val.indexes[min(pos + 1, length(val.indexes))]

function _timeout(val::TimeSeries, t_start, t_end, a, b)
    min(_next_index(val, a) - t_start, _next_index(val, b) + Millisecond(1) - t_end)
end

function _add_callback(t::TimeSlice, timeout, callback)
    callbacks = get!(t.callbacks, timeout) do
        Set()
    end
    push!(callbacks, callback)
end

members(::Anything) = anything
members(x) = unique(member for obj in x for member in obj.members)

groups(x) = unique(group for obj in x for group in obj.groups)

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
    row_processor(oc::ObjectClass, row) = first(row)
    row_processor(oc::RelationshipClass, row) = NamedTuple(row)

    return _indices(p, row_processor; kwargs...)
end

"""
    indices_as_tuples(p::Parameter; kwargs...)

Like `indices` but also yields tuples for single-dimensional entities.
"""
function indices_as_tuples(p::Parameter; kwargs...)
    return _indices(p, (_class, row) -> NamedTuple(row); kwargs...)
end

function _indices(p::Parameter, row_processor; kwargs...)
    f = _entity_filter(kwargs)
    (
        row_processor(class, row)
        for class in p.classes
        for row in eachrow(
            view(
                class.entities,
                (row -> f(row) && _default_if_missing(row, class, p.name)() !== nothing).(
                    eachrow(class.entities)
                ),
                _object_class_names(class),
            )
        )
    )
end

_default_if_missing(row::DataFrameRow, class, p_name) = _default_if_missing(row[p_name], class, p_name)
_default_if_missing(x, _class, _p_name) = x
_default_if_missing(::Missing, class, p_name) = class.default_parameter_values[p_name]

"""
    maximum_parameter_value(p::Parameter)

The singe maximum value of a `Parameter` across all its `ObjectClasses` or `RelationshipClasses`
for any`ParameterValue` types.
"""
function maximum_parameter_value(p::Parameter)
    pv_kw_iter = (
        _split_parameter_value_kwargs(p; ent_tup...) for class in p.classes for ent_tup in _entity_tuples(class)
    )
    not_nothing_pvs = (pv for (pv, _kw) in pv_kw_iter if pv() !== nothing)
    isempty(not_nothing_pvs) && return nothing
    maximum(_maximum_parameter_value(pv) for pv in not_nothing_pvs)
end

_entity_tuple(o::ObjectLike, class) = (; (class.name => o,)...)
_entity_tuple(r::RelationshipLike, class) = r

_entity_tuples(class::ObjectClass; kwargs...) = (_entity_tuple(o, class) for o in class())
_entity_tuples(class::RelationshipClass; kwargs...) = class(; _compact=false, kwargs...)

# Enable comparing Month and Year with all the other period types for computing the maximum parameter value
_upper_bound(p) = p
_upper_bound(p::Month) = p.value * Day(31)
_upper_bound(p::Year) = p.value * Day(366)

# FIXME: We need to handle empty collections here
_maximum_skipnan(itr) = maximum(x -> isnan(x) ? -Inf : _upper_bound(x), itr)

_maximum_parameter_value(pv::ParameterValue{T}) where T<:Array = _maximum_skipnan(pv.value)
function _maximum_parameter_value(pv::ParameterValue{T}) where T<:Union{TimePattern,TimeSeries}
    _maximum_skipnan(values(pv.value))
end
function _maximum_parameter_value(pv::ParameterValue{T}) where T<:Map
    _maximum_skipnan(_maximum_parameter_value.(values(pv.value)))
end
_maximum_parameter_value(pv::ParameterValue) = _upper_bound(pv.value)

"""
    add_objects!(object_class, objects)

Remove from `objects` everything that's already in `object_class`, and append the rest.
Return the modified `object_class`.
"""
function add_objects!(object_class::ObjectClass, objects::Array)
    existing = collect(object_class())
    setdiff!(objects, existing)
    df = DataFrame(; Dict(object_class.name => objects)..., copycols=false)
    _add_entities!(object_class, df)
    object_class
end

function add_object_parameter_values!(object_class::ObjectClass, parameter_values::Dict; merge_values=false)
    add_objects!(object_class, collect(keys(parameter_values)))
    _add_parameter_values!(object_class, parameter_values; merge_values=merge_values)
end

function add_object_parameter_defaults!(object_class::ObjectClass, parameter_defaults::Dict; merge_values=false)
    _add_parameter_defaults!(object_class, parameter_defaults; merge_values=merge_values)
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
    relationships = [(; zip(_object_class_names(relationship_class), obj_tup)...) for obj_tup in object_tuples]
    add_relationships!(relationship_class, relationships)
end
function add_relationships!(relationship_class::RelationshipClass, relationships::Vector)
    existing = collect(relationship_class())
    setdiff!(relationships, existing)
    df = DataFrame(;
        (cn => getproperty.(relationships, cn) for cn in _object_class_names(relationship_class))..., copycols=false
    )
    _add_entities!(relationship_class, df)
    relationship_class
end

function add_relationship_parameter_values!(
    relationship_class::RelationshipClass, parameter_values::Dict; merge_values=false
)
    add_relationships!(relationship_class, collect(keys(parameter_values)))
    _add_parameter_values!(relationship_class, parameter_values; merge_values=merge_values)
end

function add_relationship_parameter_defaults!(
    relationship_class::RelationshipClass, parameter_defaults::Dict; merge_values=false
)
    _add_parameter_defaults!(relationship_class, parameter_defaults; merge_values=merge_values)
end

function add_relationship!(relationship_class::RelationshipClass, relationship::RelationshipLike)
    add_relationships!(relationship_class, [relationship])
end

function _add_parameter_values!(class, parameter_values; merge_values)
    make_pval = merge_values ? _merge_pvals : _replace_pval
    new_param_names = unique(Iterators.flatten(keys.(values(parameter_values))))
    setdiff!(new_param_names, propertynames(class.entities))
    _insert_parameter_cols!(class, new_param_names)
    for (ent, val_by_p_name) in parameter_values
        rows = get(class.rows_by_entity, ent, get(class.rows_by_entity, Tuple(ent), []))
        for row in rows
            for (p_name, new_pval) in val_by_p_name
                class.entities[row, p_name] = make_pval(class.entities[row, p_name], new_pval)
            end
        end
    end
    class
end

function _add_parameter_defaults!(class, parameter_defaults::Dict; merge_values=false)
    new_param_names = collect(keys(parameter_defaults))
    setdiff!(new_param_names, propertynames(class.entities))
    _insert_parameter_cols!(class, new_param_names)
    _merge! = merge_values ? mergewith!(merge!) : merge!
    _merge!(class.default_parameter_values, parameter_defaults)
end

function _insert_parameter_cols!(class, parameter_names)
    insertcols!(
        class.entities,
        (
            p_name => Union{Missing,ParameterValue}[missing for i in 1:nrow(class.entities)]
            for p_name in parameter_names
        )...
    )
end

_merge_pvals(old_pval, new_pval) = merge!(old_pval, new_pval)
_merge_pvals(::Missing, new_pval) = new_pval

_replace_pval(_old_pval, new_pval) = new_pval

function add_dimension!(cls::RelationshipClass, name::Symbol, vals)
    push!(cls.intact_object_class_names, name)
    insertcols!(cls.entities, _dimensionality(cls), Dict(name => vals)...)
    empty!(cls.rows_by_entity)
    empty!(cls.rows_by_element)
    _add_relationship_class_rows!(cls.rows_by_entity, cls.rows_by_element, cls.entities[!, _object_class_names(cls)])
    nothing
end

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
    difference(left, right)

A string summarizing the differences between the `left` and the right `Dict`s.
Both `left` and `right` are mappings from string to an array.
"""
function difference(left, right)
    diff = OrderedDict(
        "object classes" => setdiff(first.(left["object_classes"]), first.(right["object_classes"])),
        "relationship classes" => setdiff(first.(left["relationship_classes"]), first.(right["relationship_classes"])),
        "parameters" => setdiff(
            (x -> x[2]).(vcat(left["object_parameters"], left["relationship_parameters"])),
            (x -> x[2]).(vcat(right["object_parameters"], right["relationship_parameters"])),
        ),
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
    realize(call, callback=nothing)

Perform the given call and return the result.

Call the given `callback` with the new result of `call` every time it would change due to `TimeSlice`s being `roll!`ed.
"""
function realize(call, callback=nothing)
    next_callback = callback !== nothing ? () -> callback(realize(call, callback)) : nothing
    try
        _do_realize(call, next_callback)
    catch e
        err_msg = "unable to evaluate expression:\n\t$call\n"
        rethrow(ErrorException("$err_msg$(sprint(showerror, e))"))
    end
end
