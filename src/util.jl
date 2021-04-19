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

const _df = DateFormat("yyyy-mm-ddTHH:MM")

function _getproperty_or_default(m::Module, name::Symbol, default=nothing)
    (name in names(m; all=true)) ? getproperty(m, name) : default
end

_next_id(id_factory::ObjectIdFactory) = id_factory.max_object_id[] += 1

_immutable(x) = x
_immutable(arr::T) where {T<:AbstractArray} = (length(arr) == 1) ? first(arr) : Tuple(arr)

function _get(d, key, backup)
    get(d, key) do
        backup[key]
    end
end

function _lookup_parameter_value(p::Parameter; _strict=true, kwargs...)
    for class in p.classes
        lookup_key, new_kwargs = _lookup_key(class; kwargs...)
        parameter_values = get(class.parameter_values, lookup_key, nothing)
        parameter_values === nothing && continue
        return _get(parameter_values, p.name, class.parameter_defaults), new_kwargs
    end
    if _strict
        error("parameter $p is not specified for argument(s) $(join(kwargs, ", "))")
    end
end

function _lookup_key(class::ObjectClass; kwargs...)
    new_kwargs = OrderedDict(kwargs...)
    pop!(new_kwargs, class.name, nothing), (; new_kwargs...)
end
function _lookup_key(class::RelationshipClass; kwargs...)
    new_kwargs = OrderedDict(kwargs...)
    objects = Tuple(pop!(new_kwargs, oc, nothing) for oc in class.object_class_names)
    nothing in objects && return nothing, (; new_kwargs...)
    objects, (; new_kwargs...)
end

_entities(class::ObjectClass; kwargs...) = class()
_entities(class::RelationshipClass; kwargs...) = class(; _compact=false, kwargs...)

_entity_key(o::ObjectLike) = o
_entity_key(r::RelationshipLike) = tuple(r...)

_entity_tuples(class::ObjectClass) = ((; Dict(class.name => o)...) for o in class())
_entity_tuples(class::RelationshipClass) = class()

function _pv_call(orig::_OriginalCall, pv::T, inds::NamedTuple) where {T<:AbstractParameterValue}
    _pv_call(_is_time_varying(T), orig, pv, inds)
end
function _pv_call(
    is_time_varying::Val{false},
    orig::_OriginalCall,
    pv::T,
    inds::NamedTuple,
) where {T<:AbstractParameterValue}
    IdentityCall(orig, pv(; inds...))
end
function _pv_call(
    is_time_varying::Val{true},
    orig::_OriginalCall,
    pv::T,
    inds::NamedTuple,
) where {T<:AbstractParameterValue}
    ParameterValueCall(orig, pv, inds)
end

_is_time_varying(::Type{MapParameterValue{K,V}}) where {K,V} = _is_time_varying(V)
_is_time_varying(::Type{MapParameterValue{DateTime,V}}) where {V} = Val(true)
_is_time_varying(::Type{T}) where {T<:TimeVaryingParameterValue} = Val(true)
_is_time_varying(::Type{T}) where {T<:AbstractParameterValue} = Val(false)

_is_associative(x) = Val(false)
_is_associative(::typeof(+)) = Val(true)
_is_associative(::typeof(*)) = Val(true)

_first(x::Array) = first(x)
_first(x) = x

function _from_to_minute(m_start::DateTime, t_start::DateTime, t_end::DateTime)
    Minute(t_start - m_start).value + 1, Minute(t_end - m_start).value
end

(p::NothingParameterValue)(; kwargs...) = nothing

(p::ScalarParameterValue)(; kwargs...) = p.value

(p::ArrayParameterValue)(; i::Union{Int64,Nothing}=nothing, kwargs...) = p(i)
(p::ArrayParameterValue)(::Nothing) = p.value
(p::ArrayParameterValue)(i::Int64) = get(p.value, i, nothing)

(p::TimePatternParameterValue)(; t::Union{TimeSlice,Nothing}=nothing, kwargs...) = p(t)
(p::TimePatternParameterValue)(::Nothing) = p.value
function (p::TimePatternParameterValue)(t::TimeSlice)
    vals = [val for (tp, val) in p.value if overlaps(t, tp)]
    isempty(vals) && return nothing
    mean(vals)
end

function _search_overlap(ts::TimeSeries, t_start::DateTime, t_end::DateTime)
    (t_start <= ts.indexes[end] && t_end > ts.indexes[1]) || return ()
    a = max(1, searchsortedlast(ts.indexes, t_start))
    b = searchsortedfirst(ts.indexes, t_end) - 1
    (a, b)
end

(p::StandardTimeSeriesParameterValue)(; t::Union{TimeSlice,Nothing}=nothing, kwargs...) = p(t)
(p::StandardTimeSeriesParameterValue)(::Nothing) = p.value
function (p::StandardTimeSeriesParameterValue)(t::TimeSlice)
    p.value.ignore_year && (t -= Year(start(t)))
    ab = _search_overlap(p.value, start(t), end_(t))
    isempty(ab) && return nothing
    a, b = ab
    a > b && return nothing
    vals = Iterators.filter(!isnan, p.value.values[a:b])
    mean(vals)
end

(p::RepeatingTimeSeriesParameterValue)(; t::Union{TimeSlice,Nothing}=nothing, kwargs...) = p(t)
(p::RepeatingTimeSeriesParameterValue)(::Nothing) = p.value
function (p::RepeatingTimeSeriesParameterValue)(t::TimeSlice)
    t_start = start(t)
    t_end = end_(t)
    p.value.ignore_year && (t_start -= Year(t_start))
    mismatch = t_start - p.value.indexes[1]
    reps = div(mismatch, p.span)
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

function _search_equal(arr::AbstractArray{T,1}, x::T) where {T}
    i = searchsortedfirst(arr, x)  # index of the first value in arr greater than or equal to x
    i <= length(arr) && arr[i] === x && return i
    nothing
end
_search_equal(arr, x) = nothing

function _search_nearest(arr::AbstractArray{T,1}, x::T) where {T}
    i = searchsortedlast(arr, x)  # index of the last value in arr less than or equal to x
    i > 0 && return i
    nothing
end
_search_nearest(arr, x) = nothing

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

function (x::_IsLowestResolution)(t::TimeSlice)
    if any(contains(r, t) for r in x.ref)
        false
    else
        push!(x.ref, t)
        true
    end
end

function (x::_IsHighestResolution)(t::TimeSlice)
    if any(iscontained(r, t) for r in x.ref)
        false
    else
        push!(x.ref, t)
        true
    end
end

mutable struct _OperatorCallTraversalState
    node_idx::Dict{Int64,Int64}
    parent_ids::Dict{Int64,Int64}
    next_id::Int64
    parent_id::Int64
    current_id::Int64
    parents::Array{Any,1}
    current::Any
    children_visited::Bool
    function _OperatorCallTraversalState(current)
        new(Dict(), Dict(), 1, 0, 1, [], current, false)
    end
end

_visit_node(st::_OperatorCallTraversalState) = (st.parent_ids[st.current_id] = st.parent_id)

function _visit_child(st::_OperatorCallTraversalState)
    if !st.children_visited && st.current isa OperatorCall
        push!(st.parents, st.current)
        st.parent_id = st.current_id
        st.current_id = st.next_id += 1
        st.node_idx[st.parent_id] = 1
        st.current = st.current.args[1]
        true
    else
        false
    end
end

function _visit_sibling(st::_OperatorCallTraversalState)
    next_index = st.node_idx[st.parent_id] + 1
    if next_index <= length(st.parents[end].args)
        st.children_visited = false
        st.node_idx[st.parent_id] = next_index
        st.current_id = st.next_id += 1
        st.current = st.parents[end].args[next_index]
        true
    else
        false
    end
end

function _revisit_parent(st::_OperatorCallTraversalState)
    st.current_id = st.parent_id
    st.parent_id = st.parent_ids[st.current_id]
    st.parent_id == 0 && return false
    st.current = pop!(st.parents)
    st.children_visited = true
    true
end

function _update_realized_vals!(vals, st::_OperatorCallTraversalState)
    parent_vals = get!(vals, st.parent_id, [])
    current_val = _realize(st.current, st.current_id, vals)
    push!(parent_vals, current_val)
end

_realize(call::OperatorCall, id::Int64, vals::Dict) = reduce(call.operator, vals[id])
_realize(x, ::Int64, ::Dict) = realize(x)

# FIXME: We need to handle empty collections here
_maximum_skipnan(itr) = maximum(x -> isnan(x) ? -Inf : x, itr)

_maximum_parameter_value(pv::ScalarParameterValue) = pv.value
_maximum_parameter_value(pv::ArrayParameterValue) = _maximum_skipnan(pv.value)
_maximum_parameter_value(pv::TimePatternParameterValue) = _maximum_skipnan(values(pv.value))
_maximum_parameter_value(pv::AbstractTimeSeriesParameterValue) = _maximum_skipnan(pv.value.values)
_maximum_parameter_value(pv::MapParameterValue) = _maximum_skipnan(_maximum_parameter_value.(pv.value.values))

"""
Non unique indices in a sorted Array.
"""
function _nonunique_inds_sorted(arr)
    nonunique_inds = []
    sizehint!(nonunique_inds, length(arr))
    for (i, (x, y)) in enumerate(zip(arr[1:(end - 1)], arr[2:end]))
        isequal(x, y) && push!(nonunique_inds, i)
    end
    nonunique_inds
end

"""
A copy of `inds` and a `copy` of vals, trimmed so they are both of the same size, sorted,
and with non unique elements of `inds` removed.
"""
function _sort_inds_vals(inds, vals)
    ind_count = length(inds)
    val_count = length(vals)
    trimmed_inds, trimmed_vals = if ind_count == val_count
        inds, vals
    elseif ind_count > val_count
        @warn("too many indices, taking only first $val_count")
        inds[1:val_count], vals
    else
        @warn("too many values, taking only first $ind_count")
        inds, vals[1:ind_count]
    end
    sorted_inds, sorted_vals = if issorted(trimmed_inds)
        trimmed_inds, trimmed_vals
    else
        p = sortperm(trimmed_inds)
        trimmed_inds[p], trimmed_vals[p]
    end
    nonunique_inds = _nonunique_inds_sorted(sorted_inds)
    if !isempty(nonunique_inds)
        @warn("repeated indices $(sorted_inds[unique(nonunique_inds)]), taking only last one")
    end
    deleteat!(sorted_inds, nonunique_inds), deleteat!(sorted_vals, nonunique_inds)
end

# parse db values
const db_df = dateformat"yyyy-mm-ddTHH:MM:SS.s"
const alt_db_df = dateformat"yyyy-mm-dd HH:MM:SS.s"

function _parse_date_time(data::String)
    try
        DateTime(data, db_df)
    catch err
        DateTime(data, alt_db_df)
    end
end

function _parse_duration(data::String)
    o = match(r"\D", data).offset  # position of first non-numeric character
    quantity, unit = parse(Int64, data[1:(o - 1)]), strip(data[o:end])
    key = (startswith(lowercase(unit), "month") || unit == "M") ? 'M' : lowercase(unit[1])
    Dict('s' => Second, 'm' => Minute, 'h' => Hour, 'd' => Day, 'M' => Month, 'y' => Year)[key](quantity)
end

_inner_type_str(::Type{Float64}) = "float"
_inner_type_str(::Type{String}) = "str"
_inner_type_str(::Type{DateTime}) = "date_time"
_inner_type_str(::Type{T}) where {T<:Period} = "duration"

_parse_inner_value(::Val{:str}, value::String) = value
_parse_inner_value(::Val{:float}, value::T) where {T<:Number} = Float64(value)
_parse_inner_value(::Val{:duration}, value::String) = _parse_duration(value)
_parse_inner_value(::Val{:date_time}, value::String) = _parse_date_time(value)

_resolution_iterator(resolution::String) = (_parse_duration(resolution),)
_resolution_iterator(resolution::Array{String,1}) = (_parse_duration(r) for r in resolution)

function _collect_ts_indexes(start::String, resolution::String, len::Int64)
    inds = DateTime[]
    sizehint!(inds, len)
    stamp = _parse_date_time(start)
    res_iter = _resolution_iterator(resolution)
    for (r, k) in zip(Iterators.cycle(res_iter), 1:len)
        push!(inds, stamp)
        stamp += r
    end
    inds
end

_map_inds_and_vals(data::Array) = (x[1] for x in data), (x[2] for x in data)
_map_inds_and_vals(data::Dict) = keys(data), values(data)

_parse_json(value) = value
_parse_json(value::Dict) = _parse_json(Val(Symbol(value["type"])), value)
_parse_json(::Val{:date_time}, value::Dict) = _parse_date_time(value["data"])
_parse_json(::Val{:duration}, value::Dict) = _parse_duration(value["data"])
_parse_json(::Val{:time_pattern}, value::Dict) = Dict(PeriodCollection(ind) => val for (ind, val) in value["data"])
_parse_json(type::Val{:time_series}, value::Dict) = _parse_json(type, get(value, "index", Dict()), value["data"])
function _parse_json(::Val{:time_series}, index::Dict, vals::Array)
    ignore_year = get(index, "ignore_year", false)
    inds = _collect_ts_indexes(index["start"], index["resolution"], length(vals))
    ignore_year && (inds .-= Year.(inds))
    TimeSeries(inds, Float64.(vals), ignore_year, get(index, "repeat", false))
end
function _parse_json(::Val{:time_series}, index::Dict, data::Dict)
    ignore_year = get(index, "ignore_year", false)
    inds = _parse_date_time.(keys(data))
    ignore_year && (inds .-= Year.(inds))
    vals = collect(Float64, values(data))
    TimeSeries(inds, vals, ignore_year, get(index, "repeat", false))
end
_parse_json(type::Val{:array}, value::Dict) = _parse_inner_value.(Val(Symbol(value["value_type"])), value["data"])
function _parse_json(::Val{:array}, ::Nothing, data::Array{T,1}) where {T}
    _parse_inner_value.(Val(Symbol(_inner_type_str(T))), data)
end
function _parse_json(::Val{:map}, value::Dict)
    raw_inds, raw_vals = _map_inds_and_vals(value["data"])
    inds = _parse_inner_value.(Val(Symbol(value["index_type"])), raw_inds)
    vals = _parse_json.(raw_vals)
    Map(inds, vals)
end

# unparse db values
_unparse_date_time(x::DateTime) = string(Dates.format(x, db_df))
function _unparse_duration(x::T) where {T<:Period}
    d = Dict(Minute => "m", Hour => "h", Day => "D", Month => "M", Year => "Y")
    suffix = get(d, T, "m")
    string(x.value, suffix)
end

_unparse_element(x::Union{Float64,String}) = x
_unparse_element(x::DateTime) = _unparse_date_time(x)
_unparse_element(x::T) where {T<:Period} = _unparse_duration(x)

function _unparse_time_pattern(pc::PeriodCollection)
    union_op = ","
    intersection_op = ";"
    range_op = "-"
    arr = []
    for name in fieldnames(PeriodCollection)
        field = getfield(pc, name)
        field === nothing && continue
        push!(arr, join([string(name, first(a), range_op, last(a)) for a in field], union_op))
    end
    join(arr, intersection_op)
end

_unparse_db_value(x) = x
_unparse_db_value(x::DateTime) = Dict("type" => "date_time", "data" => string(Dates.format(x, db_df)))
_unparse_db_value(x::T) where {T<:Period} = Dict("type" => "duration", "data" => _unparse_duration(x))
function _unparse_db_value(x::Array{T}) where {T}
    Dict("type" => "array", "value_type" => _inner_type_str(T), "data" => _unparse_element.(x))
end
function _unparse_db_value(x::TimePattern)
    Dict("type" => "time_pattern", "data" => Dict(_unparse_time_pattern(k) => v for (k, v) in x))
end
function _unparse_db_value(x::TimeSeries)
    Dict(
        "type" => "time_series",
        "index" => Dict("repeat" => x.repeat, "ignore_year" => x.ignore_year),
        "data" => OrderedDict(_unparse_date_time(i) => v for (i, v) in zip(x.indexes, x.values)),
    )
end
function _unparse_db_value(x::Map{K,V}) where {K,V}
    Dict(
        "type" => "map",
        "index_type" => _inner_type_str(K),
        "data" => [(i, _unparse_db_value(v)) for (i, v) in zip(x.indexes, x.values)],
    )
end
function _unparse_db_value(x::AbstractParameterValue)
    hasproperty(x, :value) ? _unparse_db_value(x.value) : nothing
end

function _import_spinedb_api()
    isdefined(@__MODULE__, :db_api) && return
    @eval begin
        using PyCall
        required_spinedb_api_version = v"0.10.8"
        const db_api = try
            pyimport("spinedb_api")
        catch err
            if err isa PyCall.PyError
                error(
                    """
                    The required Python package `spinedb_api` could not be found in the current Python environment
                        $(PyCall.pyprogramname)

                    You can fix this in two different ways:

                        A. Install `spinedb_api` in the current Python environment; open a terminal (command prompt on Windows) and run

                            $(PyCall.pyprogramname) -m pip install --user 'git+https://github.com/Spine-project/Spine-Database-API'

                        B. Switch to another Python environment that has `spinedb_api` installed; from Julia, run

                            ENV["PYTHON"] = "... path of the python executable ..."
                            Pkg.build("PyCall")

                        And restart Julia.
                    """,
                )
            else
                rethrow()
            end
        end
        current_version = VersionNumber(db_api.__version__)
        if current_version < required_spinedb_api_version
            error(
                """
                The required version $required_spinedb_api_version of `spinedb_api` could not be found in the current Python environment

                    $(PyCall.pyprogramname)

                You can fix this in two different ways:

                    A. Upgrade `spinedb_api` to its latest version in the current Python environment; open a terminal (command prompt on Windows) and run

                        $(PyCall.pyprogramname) -m pip upgrade --user 'git+https://github.com/Spine-project/Spine-Database-API'

                    B. Switch to another Python environment that has `spinedb_api` version $required_spinedb_api_version installed; from Julia, run

                        ENV["PYTHON"] = "... path of the python executable ..."
                        Pkg.build("PyCall")

                    And restart Julia.
                """,
            )
        end
    end
end

function _do_create_db_map(db_url::String; kwargs...)
    try
        db_api.DatabaseMapping(db_url; kwargs...)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBVersionError)
            error("""
                      The database at '$db_url' is from an older version of Spine
                      and needs to be upgraded in order to be used with the current version.

                      You can upgrade it by running `using_spinedb(db_url; upgrade=true)`.

                      WARNING: After the upgrade, the database may no longer be used
                      with previous versions of Spine.
                  """)
        else
            rethrow()
        end
    end
end

_close_db_map(db_map) = db_map.connection.close()

function _create_db_map(f::Function, db_url::String; kwargs...)
    _import_spinedb_api()
    db_map = Base.invokelatest(_do_create_db_map, db_url; kwargs...)
    try
        f(db_map)
    finally
        Base.invokelatest(_close_db_map, db_map)
    end
end

function _do_query(db_map, sq_name::Symbol)
    sq = getproperty(db_map, sq_name)
    column_names = sq.columns.keys()
    [Dict(zip(column_names, x)) for x in db_map.query(sq)]
end

_query(db_map, sq_name::Symbol) = Base.invokelatest(_do_query, db_map, sq_name)

function _do_import_data(db_map, data::Dict{Symbol,T}, comment::String) where {T<:AbstractArray}
    import_count, errors = db_api.import_data(db_map; data...)
    if import_count > 0
        try
            db_map.commit_session(comment)
        catch err
            db_map.rollback_session()
            rethrow()
        end
    end
    errors
end

_import_data(db_map, data::Dict{Symbol,T}, comment) where {T} =
    Base.invokelatest(_do_import_data, db_map, data, comment)
function _import_data(server_uri::URI, data::Dict{Symbol,T}, comment::String) where {T}
    _communicate(server_uri, "import_data", Dict(string(k) => v for (k, v) in data), comment)
end

function _communicate(server_uri::URI, request::String, args...)
    clientside = connect(server_uri.host, parse(Int, server_uri.port))
    write(clientside, JSON.json([request, args]) * '\0')
    io = IOBuffer()
    while true
        str = String(readavailable(clientside))
        write(io, str)
        if endswith(str, '\0')
            break
        end
    end
    close(clientside)
    str = String(take!(io))
    s = rstrip(str, '\0')
    if !isempty(s)
        JSON.parse(s)
    end
end
