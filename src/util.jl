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

function _getproperty(m::Module, name::Symbol, default)
    isdefined(m, name) ? getproperty(m, name) : default
end

function _getproperty!(m::Module, name::Symbol, default)
    if !isdefined(m, name)
        @eval m $name = $default
    end
    getproperty(m, name)
end

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
        parameter_values = _entity_pvals(class.parameter_values, lookup_key)
        parameter_values === nothing && continue
        return _get(parameter_values, p.name, class.parameter_defaults), new_kwargs
    end
    if _strict
        error("can't find a value of $p for argument(s) $((; kwargs...))")
    end
end

_entity_pvals(pvals, lookup_key) = _entity_pvals(pvals, lookup_key, get(pvals, lookup_key, nothing))
_entity_pvals(pvals, lookup_key, something) = something
_entity_pvals(pvals, ::Missing, ::Nothing) = nothing
_entity_pvals(pvals, ::NTuple{N,Missing}, ::Nothing) where {N} = nothing
function _entity_pvals(pvals, lookup_key, ::Nothing)
    matching = filter(k -> _matches(k, lookup_key), keys(pvals))
    if length(matching) === 1
        return pvals[first(matching)]
    end
end

function _lookup_key(class::ObjectClass; kwargs...)
    new_kwargs = OrderedDict(kwargs...)
    pop!(new_kwargs, class.name, missing), (; new_kwargs...)
end
function _lookup_key(class::RelationshipClass; kwargs...)
    new_kwargs = OrderedDict(kwargs...)
    objects = Tuple(pop!(new_kwargs, oc, missing) for oc in class.object_class_names)
    objects, (; new_kwargs...)
end

_matches(first::Tuple, second::Tuple) = all(_matches(x, y) for (x, y) in zip(first, second))
_matches(x, ::Missing) = true
_matches(x, y) = x == y

_entities(class::ObjectClass; kwargs...) = class()
_entities(class::RelationshipClass; kwargs...) = class(; _compact=false, kwargs...)

_entity_key(o::ObjectLike) = o
_entity_key(r::RelationshipLike) = tuple(r...)

_entity_tuple(o::ObjectLike, class) = (; (class.name => o,)...)
_entity_tuple(r::RelationshipLike, class) = r

_entity_tuples(class::ObjectClass; kwargs...) = (_entity_tuple(o, class) for o in class())
_entity_tuples(class::RelationshipClass; kwargs...) = class(; _compact=false, kwargs...)

_show_call(io::IO, call::Call, expr::Nothing, func::Nothing) = print(io, _do_realize(call))
_show_call(io::IO, call::Call, expr::Nothing, func::Function) = print(io, join(call.args, string(" ", func, " ")))
function _show_call(io::IO, call::Call, expr::_CallExpr, func)
    pname, kwargs = expr
    kwargs_str = join((join(kw, "=") for kw in pairs(kwargs)), ", ")
    result = _do_realize(call)
    print(io, string("{", pname, "(", kwargs_str, ") = ", result, "}"))
end

_do_realize(x) = x
_do_realize(call::Call) = _do_realize(call, call.func)
_do_realize(call::Call, ::Nothing) = call.args[1]
function _do_realize(call::Call, ::Function)
    realized_vals = Dict{Int64,Array}()
    st = _OperatorCallTraversalState(call)
    while true
        _visit_node(st)
        _visit_child(st) && continue
        _update_realized_vals!(realized_vals, st)
        _visit_sibling(st) && continue
        _revisit_parent(st) || break
    end
    vals = realized_vals[1]
    if length(vals) <= 1
        call.func(vals...)
    else
        reduce(call.func, vals)
    end
end
_do_realize(call::Call, ::T) where {T<:AbstractParameterValue} = call.func(; call.kwargs...)

_is_varying_call(call::Call, ::Nothing) = false
function _is_varying_call(call::Call, ::Function)
    st = _OperatorCallTraversalState(call)
    while true
        st.current isa Call && st.current.func isa AbstractParameterValue && return true
        _visit_node(st)
        _visit_child(st) && continue
        _visit_sibling(st) && continue
        _revisit_parent(st) || break
    end
    false
end
_is_varying_call(call::Call, ::T) where {T<:AbstractParameterValue} = true

function _pv_call(call_expr::_CallExpr, pv::T, inds::NamedTuple) where {T<:AbstractParameterValue}
    _pv_call(_is_time_varying(T), call_expr, pv, inds)
end
function _pv_call(
    is_time_varying::Val{false},
    call_expr::_CallExpr,
    pv::T,
    inds::NamedTuple,
) where {T<:AbstractParameterValue}
    Call(call_expr, pv(; inds...))
end
function _pv_call(
    is_time_varying::Val{true},
    call_expr::_CallExpr,
    pv::T,
    inds::NamedTuple,
) where {T<:AbstractParameterValue}
    Call(call_expr, pv, inds)
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

function _search_overlap(ts::TimeSeries, t_start::DateTime, t_end::DateTime)
    (t_start <= ts.indexes[end] && t_end >= ts.indexes[1]) || return ()
    a = max(1, searchsortedlast(ts.indexes, t_start))
    b = searchsortedfirst(ts.indexes, t_end) - 1
    (a, b)
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

"""
    _deleteat!(t_coll, func)

Remove key `k` in given collection if `func(t_coll[k], t_coll[l])` is `true` for any `l` other than `k`.
Used by `t_lowest_resolution` and `t_highest_resolution`.
"""
function _deleteat!(func, t_coll::Union{Array{K,1},Dict{K,T}}) where {K,T}
    n = length(t_coll)
    n <= 1 && return t_coll
    _do_deleteat!(func, t_coll)
end

function _do_deleteat!(func, t_arr::Array{K,1}) where K
    remove = _any_other(func, t_arr)
    deleteat!(t_arr, remove)
end
function _do_deleteat!(func, t_dict::Dict{K,T}) where {K,T}
    keys_ = collect(keys(t_dict))
    remove = _any_other(func, keys_)
    keep = .!remove
    keys_to_remove = deleteat!(keys_, keep)
    for k in keys_to_remove
        delete!(t_dict, k)
    end
    t_dict
end

"""
    _any_other(func, t_arr)

An `Array` of `Bool` values, where position `i` is `true` if `func(t_arr[i], t_arr[j])` is `true` for any `j` other
than `i`.
"""
function _any_other(func, t_arr::Array{T,1}) where T
    n = length(t_arr)
    result = [false for i in 1:n]
    for i in 1:n
        result[i] && continue
        t_i = t_arr[i]
        for j in Iterators.flatten((1:(i - 1),  (i + 1):n))
            result[j] && continue
            t_j = t_arr[j]
            if func(t_i, t_j)
                result[j] = true
            end
        end
    end
    result
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
    if !st.children_visited && st.current isa Call && st.current.func isa Function
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

_realize(x, ::Int64, ::Dict) = realize(x)
_realize(call::Call, id::Int64, vals::Dict) = _realize(call, call.func, id, vals)
_realize(call::Call, ::Nothing, id::Int64, vals::Dict) = realize(call)
_realize(call::Call, ::Function, id::Int64, vals::Dict) = reduce(call.func, vals[id])
_realize(call::Call, ::T, id::Int64, vals::Dict) where {T<:AbstractParameterValue} = realize(call)

# Enable comparing Month and Year with all the other period types for computing the maximum parameter value
_upper_bound(p) = p
_upper_bound(p::Month) = p.value * Day(31)
_upper_bound(p::Year) = p.value * Day(366)

# FIXME: We need to handle empty collections here
_maximum_skipnan(itr) = maximum(x -> isnan(x) ? -Inf : _upper_bound(x), itr)

_maximum_parameter_value(pv::ScalarParameterValue) = _upper_bound(pv.value)
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
    for (i, (x, y)) in enumerate(zip(arr[1 : end - 1], arr[2:end]))
        isequal(x, y) && push!(nonunique_inds, i)
    end
    nonunique_inds
end

"""
Modify `inds` and `vals` in place, trimmed so they are both of the same size, sorted,
and with non unique elements of `inds` removed.
"""
function _sort_unique!(inds, vals; merge_ok=false)
    ind_count = length(inds)
    val_count = length(vals)
    trimmed_inds, trimmed_vals = if ind_count == val_count
        inds, vals
    elseif ind_count > val_count
        @warn("too many indices, taking only first $val_count")
        deleteat!(inds, (val_count + 1):ind_count), vals
    else
        @warn("too many values, taking only first $ind_count")
        inds, deleteat!(vals, (ind_count + 1):val_count)
    end
    sorted_inds, sorted_vals = if issorted(trimmed_inds)
        trimmed_inds, trimmed_vals
    else
        p = sortperm(trimmed_inds)
        trimmed_inds_copy = copy(trimmed_inds)
        trimmed_vals_copy = copy(trimmed_vals)
        for (dst, src) in enumerate(p)
            trimmed_inds[dst] = trimmed_inds_copy[src]
            trimmed_vals[dst] = trimmed_vals_copy[src]
        end
        trimmed_inds, trimmed_vals
    end
    nonunique = _nonunique_inds_sorted(sorted_inds)
    if !merge_ok && !isempty(nonunique)
        n = length(nonunique)
        dupes = [sorted_inds[i] => sorted_vals[i] for i in nonunique[1 : min(n, 5)]]
        tail = n > 5 ? "... plus $(n - 5) more" : ""
        @warn("repeated indices, taking only last one: $dupes, $tail")          
    end
    deleteat!(sorted_inds, nonunique), deleteat!(sorted_vals, nonunique)
end

# parse/unparse db values
# parse
const db_df = dateformat"yyyy-mm-ddTHH:MM:SS.s"
const alt_db_df = dateformat"yyyy-mm-dd HH:MM:SS.s"

_inner_type_str(::Type{Float64}) = "float"
_inner_type_str(::Type{Symbol}) = "str"
_inner_type_str(::Type{String}) = "str"
_inner_type_str(::Type{DateTime}) = "date_time"
_inner_type_str(::Type{T}) where {T<:Period} = "duration"

_parse_db_value(value::Dict) = _parse_db_value(value, value["type"])
_parse_db_value(value, type::String) = _parse_db_value(value, Val(Symbol(type)))
_parse_db_value(value, ::Nothing) = _parse_db_value(value)
_parse_db_value(value::Dict, ::Val{:date_time}) = _parse_date_time(value["data"])
_parse_db_value(value::Dict, ::Val{:duration}) = _parse_duration(value["data"])
_parse_db_value(value::Dict, ::Val{:time_pattern}) = Dict(parse_time_period(ind) => val for (ind, val) in value["data"])
function _parse_db_value(value::Dict, type::Val{:time_series})
    _parse_db_value(get(value, "index", Dict()), value["data"], type)
end
function _parse_db_value(index::Dict, vals::Array, ::Val{:time_series})
    ignore_year = get(index, "ignore_year", false)
    inds = _collect_ts_indexes(index["start"], index["resolution"], length(vals))
    ignore_year && (inds .-= Year.(inds))
    TimeSeries(inds, _parse_float.(vals), ignore_year, get(index, "repeat", false))
end
function _parse_db_value(index::Dict, data::Union{OrderedDict,Dict}, ::Val{:time_series})
    ignore_year = get(index, "ignore_year", false)
    inds = _parse_date_time.(keys(data))
    ignore_year && (inds .-= Year.(inds))
    vals = _parse_float.(values(data))
    TimeSeries(inds, vals, ignore_year, get(index, "repeat", false))
end
_parse_db_value(value::Dict, type::Val{:array}) = _parse_inner_value.(value["data"], Val(Symbol(value["value_type"])))
function _parse_db_value(::Nothing, data::Array{T,1}, ::Val{:array}) where {T}
    _parse_inner_value.(data, Val(Symbol(_inner_type_str(T))))
end
function _parse_db_value(value::Dict, ::Val{:map})
    raw_inds, raw_vals = _map_inds_and_vals(value["data"])
    inds = _parse_inner_value.(raw_inds, Val(Symbol(value["index_type"])))
    vals = _parse_db_value.(raw_vals)
    Map(inds, vals)
end
_parse_db_value(value::Float64) = isinteger(value) ? Int64(value) : value
_parse_db_value(value) = value

function _parse_date_time(data::String)
    try
        DateTime(data, db_df)
    catch err
        DateTime(data, alt_db_df)
    end
end

function _parse_duration(data::String)
    o = match(r"\D", data).offset  # position of first non-numeric character
    quantity, unit = parse(Int64, data[1 : o - 1]), strip(data[o:end])
    key = (startswith(lowercase(unit), "month") || unit == "M") ? 'M' : lowercase(unit[1])
    Dict('s' => Second, 'm' => Minute, 'h' => Hour, 'd' => Day, 'M' => Month, 'y' => Year)[key](quantity)
end

_parse_float(x) = Float64(x)
_parse_float(::Nothing) = NaN

_parse_inner_value(value::String, ::Val{:str}) = value
_parse_inner_value(value::T, ::Val{:float}) where {T<:Number} = _parse_float(value)
_parse_inner_value(value::String, ::Val{:duration}) = _parse_duration(value)
_parse_inner_value(value::String, ::Val{:date_time}) = _parse_date_time(value)

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

_map_inds_and_vals(data::Matrix) = data[:,1], data[:,2]
_map_inds_and_vals(data::Array) = (x[1] for x in data), (x[2] for x in data)
_map_inds_and_vals(data::Dict) = keys(data), values(data)

# unparse
_unparse_date_time(x::DateTime) = string(Dates.format(x, db_df))
function _unparse_duration(x::T) where {T<:Period}
    d = Dict(Minute => "m", Hour => "h", Day => "D", Month => "M", Year => "Y")
    suffix = get(d, T, "m")
    string(x.value, suffix)
end

_unparse_element(x::Union{Float64,String}) = x
_unparse_element(x::DateTime) = _unparse_date_time(x)
_unparse_element(x::T) where {T<:Period} = _unparse_duration(x)

function _unparse_time_pattern(union::UnionOfIntersections)
    union_op = ","
    intersection_op = ";"
    range_op = "-"
    union_arr = [
        join([string(i.key, i.lower, range_op, i.upper) for i in intersection], intersection_op)
        for intersection in union
    ]
    join(union_arr, union_op)
end

_unparse_map_value(x::NothingParameterValue) = _unparse_map_value(nothing)
_unparse_map_value(x::AbstractParameterValue) = _unparse_map_value(x.value)
_unparse_map_value(x) = _add_db_type!(db_value(x), x)

function _add_db_type!(db_val::Dict, x)
    db_val["type"] = _db_type(x)
    db_val
end
_add_db_type!(db_val, x) = db_val

"""A custom JSONContext that serializes NaN values in complex parameter values as 'NaN'"""
mutable struct _ParameterValueJSONContext <: JSON.Writer.JSONContext
    underlying::JSON.Writer.JSONContext
end

for delegate in (:indent, :delimit, :separate, :begin_array, :end_array, :begin_object, :end_object)
    @eval JSON.Writer.$delegate(ctx::_ParameterValueJSONContext) = JSON.Writer.$delegate(ctx.underlying)
end
Base.write(ctx::_ParameterValueJSONContext, byte::UInt8) = write(ctx.underlying, byte)

JSON.Writer.show_null(ctx::_ParameterValueJSONContext) = print(ctx, "NaN")

function _serialize_pv(obj::Dict)
    io = IOBuffer()
    ctx = _ParameterValueJSONContext(JSON.Writer.CompactContext(io))
    JSON.print(ctx, obj)
    String(take!(io))
end
_serialize_pv(x) = JSON.json(x)

_db_type(x) = nothing
_db_type(x::Dict) = x["type"]
_db_type(::DateTime) = "date_time"
_db_type(::T) where {T<:Period} = "duration"
_db_type(x::Array{T}) where {T} = "array"
_db_type(x::TimePattern) = "time_pattern"
_db_type(x::TimeSeries) = "time_series"
_db_type(x::Map{K,V}) where {K,V} = "map"

# db api
const _required_spinedb_api_version = v"0.23.2"

const _client_version = 6

_spinedb_api_not_found(pyprogramname) = """
The required Python package `spinedb_api` could not be found in the current Python environment
    $pyprogramname

You can fix this in two different ways:

    A. Install `spinedb_api` in the current Python environment; open a terminal (command prompt on Windows) and run

        $pyprogramname -m pip install --user 'git+https://github.com/Spine-project/Spine-Database-API'

    B. Switch to another Python environment that has `spinedb_api` installed; from Julia, run

        ENV["PYTHON"] = "... path of the python executable ..."
        Pkg.build("PyCall")

    And restart Julia.
"""

const _required_spinedb_api_version_not_found_py_call(pyprogramname) = """
The required version $_required_spinedb_api_version of `spinedb_api` could not be found in the current Python environment

    $pyprogramname

You can fix this in two different ways:

    A. Upgrade `spinedb_api` to its latest version in the current Python environment; open a terminal (command prompt on Windows) and run

        $pyprogramname -m pip upgrade --user 'git+https://github.com/Spine-project/Spine-Database-API'

    B. Switch to another Python environment that has `spinedb_api` version $_required_spinedb_api_version installed; from Julia, run

        ENV["PYTHON"] = "... path of the python executable ..."
        Pkg.build("PyCall")

    And restart Julia.
"""

const _required_spinedb_api_version_not_found_server = """
The required version $_required_spinedb_api_version of `spinedb_api` could not be found.
Please update Spine Toolbox by following the instructions at
    
    https://github.com/Spine-project/Spine-Toolbox#installation
"""

function _parse_spinedb_api_version(version)
    # Version number shortened and tweaked to avoid PEP 440 -> SemVer issues
    VersionNumber(replace(join(split(version, '.')[1:3],'.'), '-' => '+'))
end
_parse_spinedb_api_version(::Nothing) = VersionNumber(0)

function _import_spinedb_api()
    isdefined(@__MODULE__, :db_api) && return
    @eval begin
        using PyCall
        const db_api, db_server = try
            pyimport("spinedb_api"), pyimport("spinedb_api.spine_db_server")
        catch err
            if err isa PyCall.PyError
                error(_spinedb_api_not_found(PyCall.pyprogramname))
            else
                rethrow()
            end
        end
        spinedb_api_version = _parse_spinedb_api_version(db_api.__version__)
        if spinedb_api_version < _required_spinedb_api_version
            error(_required_spinedb_api_version_not_found_py_call(PyCall.pyprogramname))
        end        
    end
end

_handlers = Dict()

_do_create_db_handler(db_url::String, upgrade::Bool) = db_server.DBHandler(db_url, upgrade)

_do_close_db_handler(handler) = handler.close()

function _create_db_handler(db_url::String, upgrade::Bool)
    _import_spinedb_api()
    handler = Base.invokelatest(_do_create_db_handler, db_url, upgrade)
    atexit(() -> _close_db_handler(handler))
    handler
end

_close_db_handler(handler) = Base.invokelatest(_do_close_db_handler, handler)

function _db(f, url; upgrade=false)
    uri = URI(url)
    if uri.scheme == "http"
        f(uri)
    else
        handler = get(_handlers, url, nothing)
        if handler !== nothing
            f(handler)
        else
            handler = _create_db_handler(url, upgrade)
            result = f(handler)
            _close_db_handler(handler)
            result
        end
    end
end

function _process_db_answer(answer::Dict)
    result = get(answer, "result", nothing)
    err = get(answer, "error", nothing)
    _process_db_answer(result, err)
end
_process_db_answer(answer) = answer  # Legacy
_process_db_answer(result, err::Nothing) = result
function _process_db_answer(result, err::Int64)
    if err == 1
        required_client_version = result
        error(
            "version mismatch: DB server requires client version $required_client_version, ",
            "whereas current version is $_client_version; ",
            "please update SpineInterface"
        )
    else
        error("unknown error code $err returned by DB server")
    end
end
_process_db_answer(result, err) = error(string(err))

const _EOT = '\u04'  # End of transmission
const _START_OF_TAIL = '\u1f'  # Unit separator
const _START_OF_ADDRESS = '\u91'  # Private Use 1
const _ADDRESS_SEP = ':'

struct _TailSerialization <: JSON.CommonSerialization
    tail::Vector{UInt8}
    _TailSerialization() = new(Vector{UInt8}())
end

function JSON.show_json(io::JSON.StructuralContext, s::_TailSerialization, bytes::Vector{UInt8})
    tip = length(s.tail)
    from, to = tip, tip + length(bytes) - 1  # 0-based
    marker = string(_START_OF_ADDRESS, from, _ADDRESS_SEP, to)
    append!(s.tail, bytes)
    JSON.show_json(io, JSON.StandardSerialization(), marker)
end

function _encode(obj)
    s = _TailSerialization()
    body = sprint(JSON.show_json, s, obj)
    vcat(Vector{UInt8}(body), UInt8(_START_OF_TAIL), s.tail)
end

function _decode(io)
    bytes = take!(io)
    i = findlast(bytes .== UInt8(_START_OF_TAIL))
    body, tail = bytes[1 : i - 1], bytes[i + 1 : end]
    o = JSON.parse(String(body))
    _expand_addresses!(o, tail)
end

function _expand_addresses!(o::Dict, tail)
    for (k, v) in o
        o[k] = _expand_addresses!(v, tail)
    end
    o
end
function _expand_addresses!(o::Array, tail)
    for (k, e) in enumerate(o)
        o[k] = _expand_addresses!(e, tail)
    end
    o
end
function _expand_addresses!(o::String, tail)
    startswith(o, _START_OF_ADDRESS) || return o
    marker = lstrip(o, _START_OF_ADDRESS)
    from, to = (parse(Int64, x) + 1 for x in split(marker, _ADDRESS_SEP))  # 1-based
    tail[from:to]
end
_expand_addresses!(o, tail) = o

function _do_run_server_request(server_uri::URI, full_request::Array; timeout=Inf)
    clientside = connect(server_uri.host, parse(Int, server_uri.port))
    write(clientside, _encode(full_request))
    write(clientside, UInt8(_EOT))
    io = IOBuffer()
    elapsed = 0
    while true
        bytes = readavailable(clientside)
        if !isempty(bytes)
            write(io, bytes)
            elapsed = 0
            if bytes[end] == UInt8(_EOT)
                break
            end
            continue
        end
        if elapsed > timeout
            close(clientside)
            return
        end
        sleep(0.02)
        elapsed += 0.02
    end
    close(clientside)
    answer = _decode(io)
    isempty(answer) && return  # FIXME: needed?
    _process_db_answer(answer)
end

_handle_request(dbh, request) = dbh.handle_request(request)

function _run_server_request(db, request::String)
    _run_server_request(db, request, (), Dict())
end
function _run_server_request(db, request::String, args::Tuple)
    _run_server_request(db, request, args, Dict())
end
function _run_server_request(db, request::String, kwargs::Dict)
    _run_server_request(db, request, (), kwargs)
end
function _run_server_request(server_uri::URI, request::String, args::Tuple, kwargs::Dict)
    _do_run_server_request(server_uri, ["get_db_url", ()])  # to trigger compilation
    elapsed = @elapsed _do_run_server_request(server_uri, ["get_db_url", ()])
    spinedb_api_version = _do_run_server_request(server_uri, ["get_api_version", ()]; timeout=10 * elapsed)
    if _parse_spinedb_api_version(spinedb_api_version) < _required_spinedb_api_version
        error(_required_spinedb_api_version_not_found_server)
    end
    full_request = [request, args, kwargs, _client_version]
    _do_run_server_request(server_uri, full_request)
end
function _run_server_request(dbh, request::String, args::Tuple, kwargs::Dict)
    full_request = [request, args, kwargs, _client_version]
    request = Base.invokelatest(pybytes, _encode(full_request))
    io = IOBuffer()
    str = Base.invokelatest(_handle_request, dbh, request)
    write(io, str)
    answer = _decode(io)
    _process_db_answer(answer)
end

function _export_data(db; filters=Dict())
    isempty(filters) || _run_server_request(db, "apply_filters", (filters,))
    data = _run_server_request(db, "export_data")
    isempty(filters) || _run_server_request(db, "clear_filters")
    data
end

function _import_data(db, data::Dict{Symbol,T}, comment::String) where {T}
    _run_server_request(db, "import_data", (Dict(string(k) => v for (k, v) in data), comment))
end

function _run_request(db, request::String, args::Tuple, kwargs::Dict)
    _run_server_request(db, request, args, kwargs)
end

function _to_dict(obj_cls::ObjectClass)
    Dict(
        :object_classes => [obj_cls.name],
        :object_parameters => [
            [obj_cls.name, parameter_name, unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in obj_cls.parameter_defaults
        ],
        :objects => [[obj_cls.name, object.name] for object in obj_cls.objects],
        :object_parameter_values => [
            [obj_cls.name, object.name, parameter_name, unparse_db_value(parameter_value)]
            for (object, parameter_values) in obj_cls.parameter_values
            for (parameter_name, parameter_value) in parameter_values
        ]
    )
end
function _to_dict(rel_cls::RelationshipClass)
    Dict(
        :object_classes => unique(rel_cls.intact_object_class_names),
        :objects => unique(
            [obj_cls_name, obj.name]
            for relationship in rel_cls.relationships
            for (obj_cls_name, obj) in zip(rel_cls.intact_object_class_names, relationship)
        ), 
        :relationship_classes => [[rel_cls.name, rel_cls.intact_object_class_names]],
        :relationship_parameters => [
            [rel_cls.name, parameter_name, unparse_db_value(parameter_default_value)]
            for (parameter_name, parameter_default_value) in rel_cls.parameter_defaults
        ],
        :relationships => [
            [rel_cls.name, [obj.name for obj in relationship]] for relationship in rel_cls.relationships
        ],
        :relationship_parameter_values => [
            [rel_cls.name, [obj.name for obj in relationship], parameter_name, unparse_db_value(parameter_value)]
            for (relationship, parameter_values) in rel_cls.parameter_values
            for (parameter_name, parameter_value) in parameter_values
        ]
    )
end

_common_indexes(x::TimeSeries, y::TimeSeries) = sort!(unique!(vcat(x.indexes, y.indexes)))
_common_indexes(x::TimeSeries, y::TimePattern) = copy(x.indexes)
_common_indexes(x::TimePattern, y::TimeSeries) = copy(y.indexes)

"""
Generate indexes and values for a time series by applying f over arguments x and y.
"""
function _timedata_operation(f, x, y)
    indexes = _common_indexes(x, y)
    param_val_x = parameter_value(x)
    param_val_y = parameter_value(y)
    values = Any[(param_val_x(ind), param_val_y(ind)) for ind in indexes]
    to_remove = findall(x -> nothing in x, values)
    deleteat!(indexes, to_remove)
    deleteat!(values, to_remove)
    map!(x -> f(x...), values, values)
    indexes, values
end

"""
Append an increasing integer to each repeated element in `name_list`, and return the modified `name_list`.
"""
function _fix_name_ambiguity(intact_name_list::Array{Symbol,1})
    name_list = copy(intact_name_list)
    for ambiguous in Iterators.filter(name -> count(name_list .== name) > 1, unique(name_list))
        for (k, index) in enumerate(findall(name_list .== ambiguous))
            name_list[index] = Symbol(name_list[index], k)
        end
    end
    name_list
end

"""An `Array` with the object class names of an entity."""
_object_class_names(entity::NamedTuple) = [_object_class_name(key, val) for (key, val) in pairs(entity)]
_object_class_name(key, val::ObjectLike) = _object_class_name(key, val, val.class_name)
_object_class_name(key, val::ObjectLike, class_name::Symbol) = string(class_name)
_object_class_name(key, val::ObjectLike, ::Nothing) = string(key)
_object_class_name(key, val) = string(key)

_get_range(arr, range) = arr[range]
_get_range(arr, ::Nothing) = arr

_inner_value(x) = x
_inner_value(x::NothingParameterValue) = nothing
_inner_value(x::AbstractParameterValue) = x.value