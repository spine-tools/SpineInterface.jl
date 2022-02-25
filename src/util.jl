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

_entity_tuple(o::ObjectLike, class) = (; Dict(class.name => o)...)
_entity_tuple(r::RelationshipLike, class) = r

_entity_tuples(class::ObjectClass; kwargs...) = (_entity_tuple(o, class) for o in class())
_entity_tuples(class::RelationshipClass; kwargs...) = class(; _compact=false, kwargs...)

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
    for (i, (x, y)) in enumerate(zip(arr[1:(end - 1)], arr[2:end]))
        isequal(x, y) && push!(nonunique_inds, i)
    end
    nonunique_inds
end

"""
Modify `inds` and `vals` in place, trimmed so they are both of the same size, sorted,
and with non unique elements of `inds` removed.
"""
function _sort_unique!(inds, vals)
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

_parse_float(x) = Float64(x)
_parse_float(::Nothing) = NaN

_inner_type_str(::Type{Float64}) = "float"
_inner_type_str(::Type{Symbol}) = "str"
_inner_type_str(::Type{String}) = "str"
_inner_type_str(::Type{DateTime}) = "date_time"
_inner_type_str(::Type{T}) where {T<:Period} = "duration"

_parse_inner_value(::Val{:str}, value::String) = value
_parse_inner_value(::Val{:float}, value::T) where {T<:Number} = _parse_float(value)
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

# db api
const _required_spinedb_api_version = v"0.16.4"

const _client_version = 1

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
        msg = "version mismatch: DB server requires client version $required_client_version, "
        msg *= "whereas current version is $_client_version; "
        msg *= "please update SpineInterface"
        error(msg)
    else
        error("unknown error code $err returned by DB server")
    end
end
_process_db_answer(result, err) = error(string(err))

function _do_run_server_request(server_uri::URI, request::String, args::Tuple, kwargs::Dict; timeout=Inf)
    _do_run_server_request(server_uri, [request, args, kwargs, _client_version]; timeout=timeout)
end
function _do_run_server_request(server_uri::URI, full_request::Array; timeout=Inf)
    clientside = connect(server_uri.host, parse(Int, server_uri.port))
    write(clientside, JSON.json(full_request) * '\0')
    io = IOBuffer()
    elapsed = 0
    while true
        str = String(readavailable(clientside))
        write(io, str)
        if endswith(str, '\0')
            break
        end
        if !isempty(str)
            elapsed = 0
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
    str = String(take!(io))
    s = rstrip(str, '\0')
    isempty(s) && return
    answer = JSON.parse(s)
    _process_db_answer(answer)
end

function _run_server_request(server_uri::URI, request::String)
    _run_server_request(server_uri, request, (), Dict())
end
function _run_server_request(server_uri::URI, request::String, args::Tuple)
    _run_server_request(server_uri, request, args, Dict())
end
function _run_server_request(server_uri::URI, request::String, kwargs::Dict)
    _run_server_request(server_uri, request, (), kwargs)
end
function _run_server_request(server_uri::URI, request::String, args::Tuple, kwargs::Dict)
    _do_run_server_request(server_uri, ["get_db_url", ()])  # to trigger compilation
    elapsed = @elapsed _do_run_server_request(server_uri, ["get_db_url", ()])
    spinedb_api_version = _do_run_server_request(server_uri, ["get_api_version", ()]; timeout=10 * elapsed)
    if _parse_spinedb_api_version(spinedb_api_version) < _required_spinedb_api_version
        error(_required_spinedb_api_version_not_found_server)
    end
    _do_run_server_request(server_uri, request, args, kwargs)
end

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

_do_create_db_handler(db_url::String, upgrade::Bool) = db_server.DBHandler(db_url, upgrade)

function _create_db_handler(db_url::String, upgrade::Bool)
    _import_spinedb_api()
    Base.invokelatest(_do_create_db_handler, db_url, upgrade)
end

function _do_apply_filters(dbh, filters::Dict)
    _process_db_answer(dbh.apply_filters(filters))
end

function _do_clear_filters(dbh)
    _process_db_answer(dbh.clear_filters())
end

function _do_export_data(dbh)
    dbh.export_data()
    _process_db_answer(dbh.export_data())
end

function _export_data(db_url::String; upgrade=false, filters=Dict())
    dbh = _create_db_handler(db_url, upgrade)
    isempty(filters) || Base.invokelatest(_do_apply_filters, dbh, filters)
    data = Base.invokelatest(_do_export_data, dbh)
    isempty(filters) || Base.invokelatest(_do_clear_filters, dbh)
    data
end
function _export_data(server_uri::URI; upgrade=nothing, filters=Dict())
    isempty(filters) || _run_server_request(server_uri, "apply_filters", (filters,))
    data = _run_server_request(server_uri, "export_data")
    isempty(filters) || _run_server_request(server_uri, "clear_filters")
    data
end

_do_import_data(dbh, data, comment) = _process_db_answer(dbh.import_data(data, comment))

_convert_arrays_to_py_vectors(d::Dict) = Dict(k => _convert_arrays_to_py_vectors(v) for (k, v) in d)
_convert_arrays_to_py_vectors(t::Tuple) = Tuple(_convert_arrays_to_py_vectors(x) for x in t)
_convert_arrays_to_py_vectors(a::Array) = Base.invokelatest(PyVector, _convert_arrays_to_py_vectors.(a))
_convert_arrays_to_py_vectors(x) = x

function _import_data(db_url::String, data::Dict{Symbol,T}, comment::String; upgrade=true) where {T}
    dbh = _create_db_handler(db_url, upgrade)
    data = _convert_arrays_to_py_vectors(data)
    Base.invokelatest(_do_import_data, dbh, data, comment)
end
function _import_data(server_uri::URI, data::Dict{Symbol,T}, comment::String; upgrade=nothing) where {T}
    _run_server_request(server_uri, "import_data", (Dict(string(k) => v for (k, v) in data), comment))
end

function _do_run_request(dbh, request::String, args::Tuple, kwargs::Dict)
    _process_db_answer(getproperty(dbh, Symbol(request))(args...; kwargs...))
end

function _run_request(db_url::String, request::String, args::Tuple, kwargs::Dict; upgrade=false)
    dbh = _create_db_handler(db_url, upgrade)
    args = _convert_arrays_to_py_vectors(args)
    kwargs = _convert_arrays_to_py_vectors(kwargs)
    Base.invokelatest(_do_run_request, dbh, request, args, kwargs)
end
function _run_request(server_uri::URI, request::String, args::Tuple, kwargs::Dict; upgrade=nothing)
    _run_server_request(server_uri, request, args, kwargs)
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

"""
    _apply_or_nothing(f, x, y)

The result of applying `f` on `x` and `y`, or `nothing` if either `x` or `y` is `nothing`.
"""
_apply_or_nothing(f, x, y) = f(x, y)
_apply_or_nothing(f, ::Nothing, y) = nothing
_apply_or_nothing(f, x, ::Nothing) = nothing

"""
    _remove_nothing_values!(inds, vals)

Remove `nothing` from `vals`, and corresponding positions from `inds`.
"""
function _remove_nothing_values!(inds, vals)
    to_remove = findall(isnothing, vals)
    deleteat!(inds, to_remove)
    deleteat!(vals, to_remove)
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