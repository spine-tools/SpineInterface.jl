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

Base.intersect(::Anything, s) = s
Base.intersect(s, ::Anything) = s
Base.intersect(::Anything, ::Anything) = anything

Base.in(item, ::Anything) = true

Base.iterate(o::Union{Object,TimeSlice}) = iterate((o,))
Base.iterate(o::Union{Object,TimeSlice}, state::T) where {T} = iterate((o,), state)
Base.iterate(v::ParameterValue{T}) where {T<:_Scalar} = iterate((v,))
Base.iterate(v::ParameterValue{T}, state) where {T<:_Scalar} = iterate((v,), state)
function Base.iterate(x::Union{TimeSeries,Map}, state=1)
    if state > length(x)
        nothing
    else
        (x.indexes[state] => x.values[state]), state + 1
    end
end

Base.length(t::Union{Object,TimeSlice}) = 1
Base.length(v::ParameterValue{T}) where {T<:_Scalar} = 1
Base.length(x::Union{TimeSeries,Map}) = length(x.indexes)

Base.isless(x::Object, y::Object) = x.name < y.name
Base.isless(a::TimeSlice, b::TimeSlice) = tuple(start(a), end_(a)) < tuple(start(b), end_(b))
Base.isless(t::TimeSlice, dt::DateTime) = isless(end_(t), dt)
Base.isless(dt::DateTime, t::TimeSlice) = isless(dt, start(t))
Base.isless(v1::ParameterValue{T}, v2::ParameterValue{T}) where {T<:_Scalar} = v1.value < v2.value
Base.isless(scalar::Number, ts::TimeSeries) = all(isless(scalar, v) for v in ts.values)
Base.isless(ts::TimeSeries, scalar::Number) = all(isless(v, scalar) for v in ts.values)

Base.:(==)(x::T, y::T) where T<:Union{Object,TimeSlice} = x.id == y.id
Base.:(==)(x::TimeSeries, y::TimeSeries) = all(
    [getfield(x, field) == getfield(y, field) for field in fieldnames(TimeSeries)]
)
Base.:(==)(x::Map, y::Map) = all(
    [getfield(x, field) == getfield(y, field) for field in fieldnames(Map)]
)
Base.:(==)(x::ParameterValue, y::ParameterValue) = x.value == y.value
Base.:(==)(scalar::Number, ts::TimeSeries) = all(scalar == v for v in ts.values)
Base.:(==)(ts::TimeSeries, scalar::Number) = scalar == ts
function Base.:(==)(x::Call, y::Call)
    x.func == y.func && _isequal(x.func, x.args, y.args) && pairs(x.kwargs) == pairs(y.kwargs)
end

Base.isequal(x::ParameterValue, y::ParameterValue) = isequal(x.value, y.value)
Base.isequal(x::T, y::T) where T<:Union{TimeSeries,Map} = all(
    [isequal(getfield(x, field), getfield(y, field)) for field in fieldnames(T)]
)
function Base.isequal(x::Call, y::Call)
    isequal(x.func, y.func) && _isequal(x.func, x.args, y.args) && pairs(x.kwargs) == pairs(y.kwargs)
end

_isequal(::Union{typeof(+),typeof(*)}, x, y) = length(x) == length(y) && all(z in y for z in x)
_isequal(op, x, y) = x == y

Base.:(<=)(scalar::Number, ts::TimeSeries) = all(scalar <= v for v in ts.values)
Base.:(<=)(ts::TimeSeries, scalar::Number) = all(v <= scalar for v in ts.values)
Base.:(<=)(t::TimeSlice, dt::DateTime) = end_(t) <= dt

Base.hash(::Anything) = zero(UInt64)
Base.hash(o::Union{Object,TimeSlice}) = o.id
Base.hash(r::RelationshipLike{K}) where {K} = hash(values(r))

Base.show(io::IO, ::Anything) = print(io, "anything")
Base.show(io::IO, o::Object) = print(io, o.name)
function Base.show(io::IO, t::TimeSlice)
    print(io, string(Dates.format(start(t), _df)), "~(", t.period_duration, ")~>", Dates.format(end_(t), _df))
end
Base.show(io::IO, s::_StartRef) = print(io, string(Dates.format(start(s.time_slice), _df)))
Base.show(io::IO, oc::ObjectClass) = print(io, oc.name)
Base.show(io::IO, rc::RelationshipClass) = print(io, rc.name)
Base.show(io::IO, p::Parameter) = print(io, p.name)
Base.show(io::IO, v::ParameterValue{T}) where T = print(io, string("ParameterValue(", v.value, ")"))
Base.show(io::IO, call::Call) = _show_call(io, call, call.call_expr, call.func)
function Base.show(io::IO, union::UnionOfIntersections)
    d = Dict{Symbol,String}(
        :Y => "year",
        :M => "month",
        :D => "day",
        :WD => "day of the week",
        :h => "hour",
        :m => "minute",
        :s => "second",
    )
    intersections = [
        join(["$(d[i.key]) from $(i.lower) to $(i.upper)" for i in intersection], ", and ")
        for intersection in union
    ]
    print(io, join(intersections, ", or "))
end
function Base.show(io::IO, ts::TimeSeries)
    body = if isempty(ts.indexes)
        ""
    elseif length(ts.indexes) < 10
        join((string(i, "=>", v) for (i, v) in zip(ts.indexes, ts.values)), ", ")
    else
        first_ = string(first(ts.indexes), "=>", first(ts.values))
        last_ = string(last(ts.indexes), "=>", last(ts.values))
        "$first_ ... $last_"
    end
    print(io, "TimeSeries[$body](ignore_year=$(ts.ignore_year), repeat=$(ts.repeat))")
end

_show_call(io::IO, call::Call, expr::Nothing, func::Nothing) = print(io, _do_realize(call, nothing))
function _show_call(io::IO, call::Call, expr::Nothing, func::Function)
    call_str = if length(call.args) == 1
        string(func, "(", call.args[1], ")")
    else
        join(call.args, string(" ", func, " "))
    end
    print(io, call_str)
end
function _show_call(io::IO, call::Call, expr::_CallExpr, func::ParameterValue)
    pname, kwargs = expr
    kwargs_str = join((join(kw, "=") for kw in pairs(kwargs)), ", ")
    result = _do_realize(call, nothing)
    print(io, string("{", pname, "(", kwargs_str, ") = ", result, "}"))
end

Base.convert(::Type{Call}, x::T) where {T} = Call(x)
Base.convert(::Type{Call}, x::Call) = x

Base.copy(ts::TimeSeries{T}) where {T} = TimeSeries(copy(ts.indexes), copy(ts.values), ts.ignore_year, ts.repeat)
Base.copy(c::ParameterValue) = parameter_value(c.value)
Base.copy(c::Call) = Call(c.func, c.args, c.kwargs, c.call_expr)

Base.zero(::Type{T}) where {T<:Call} = Call(zero(Float64))
Base.zero(::Call) = Call(zero(Float64))

Base.iszero(x::Call) = _iszero(x.func, x)

_iszero(::Union{Nothing,typeof(+),typeof(-)}, x) = all(iszero(a) for a in x.args)
_iszero(::typeof(*), x) = any(iszero(a) for a in x.args)
_iszero(::typeof(/), x) = iszero(x.args[1])
_iszero(::T, x) where T = false

Base.one(::Type{T}) where {T<:Call} = Call(one(Float64))
Base.one(::Call) = Call(one(Float64))

Base.:+(ts::TimeSeries{V}) where V = +(zero(V), ts)
Base.:+(ts::TimeSeries, num::Number) = timedata_operation(+, ts, num)
Base.:+(num::Number, ts::TimeSeries) = timedata_operation(+, num, ts)
Base.:+(tp::TimePattern, num::Number) = timedata_operation(+, tp, num)
Base.:+(num::Number, tp::TimePattern) = timedata_operation(+, num, tp)
Base.:+(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(+, ts1, ts2)
Base.:+(ts::TimeSeries, tp::TimePattern) = timedata_operation(+, ts, tp)
Base.:+(tp::TimePattern, ts::TimeSeries) = timedata_operation(+, tp, ts)
Base.:+(tp1::TimePattern, tp2::TimePattern) = timedata_operation(+, tp1, tp2)
Base.:+(m::Map, x::Union{Number,TimeSeries,TimePattern}) = timedata_operation(+, m, x)
Base.:+(x::Union{Number,TimeSeries,TimePattern}, m::Map) = timedata_operation(+, x, m)
Base.:+(m1::Map, m2::Map) = timedata_operation(+, m1, m2)
Base.:+(t::TimeSlice, p::Period) = TimeSlice(start(t) + p, start(t) + p + (end_(t) - start(t)), duration(t), blocks(t))
Base.:+(x::Call) = x
Base.:+(x::Call, y) = _sum_call([_args(+, x); y])
Base.:+(x, y::Call) = _sum_call([x; _args(+, y)])
Base.:+(x::Call, y::Call) = _sum_call([_args(+, x); _args(+, y)])

function _sum_call(args)
    numerical_args = filter(x -> x isa Number, args)
    non_numerical_args = filter(x -> !(x isa Number), args)
    numerical_term = sum(numerical_args; init=0.0)
    if isempty(non_numerical_args)
        Call(numerical_term)
    else
        args_count = ((a, count(x -> x === a, non_numerical_args)) for a in unique(non_numerical_args))
        final_args = [k == 1 ? a : k * a for (a, k) in args_count]
        if !iszero(numerical_term)
            push!(final_args, numerical_term)
        end
        if length(final_args) == 1
            Call(final_args[1])
        else
            diff_calls = _split!(x -> x isa Call && x.func == -, final_args)
            pos_args = [x.args[1] for x in diff_calls if length(x.args) > 1]
            neg_args = [length(x.args) > 1 ? x.args[2] : x.args[1] for x in diff_calls]
            append!(pos_args, final_args)
            pos_result = _final_sum_call(pos_args)
            neg_result = _final_sum_call(neg_args)
            if neg_result === nothing
                pos_result
            elseif pos_result === nothing
                -neg_result
            else
                pos_result - neg_result
            end
        end
    end
end

function _split!(f, arr)
    i = findall(f, arr)
    result = arr[i]
    deleteat!(arr, i)
    result
end

function _final_sum_call(args)
    if isempty(args)
        nothing
    elseif length(args) == 1
        Call(args[1])
    else
        Call(+, args)
    end
end

Base.:-(ts::TimeSeries{V}) where V = -(zero(V), ts)
Base.:-(ts::TimeSeries, num::Number) = timedata_operation(-, ts, num)
Base.:-(num::Number, ts::TimeSeries) = timedata_operation(-, num, ts)
Base.:-(tp::TimePattern, num::Number) = timedata_operation(-, tp, num)
Base.:-(num::Number, tp::TimePattern) = timedata_operation(-, num, tp)
Base.:-(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(-, ts1, ts2)
Base.:-(ts::TimeSeries, tp::TimePattern) = timedata_operation(-, ts, tp)
Base.:-(tp::TimePattern, ts::TimeSeries) = timedata_operation(-, tp, ts)
Base.:-(tp1::TimePattern, tp2::TimePattern) = timedata_operation(-, tp1, tp2)
Base.:-(m::Map, x::Union{Number,TimeSeries,TimePattern}) = timedata_operation(-, m, x)
Base.:-(x::Union{Number,TimeSeries,TimePattern}, m::Map) = timedata_operation(-, x, m)
Base.:-(m1::Map, m2::Map) = timedata_operation(-, m1, m2)
Base.:-(t::TimeSlice, p::Period) = (+)(t, -p)
Base.:-(x::Call) = Call(-, [_arg(x)])
Base.:-(x::Call, y) = _diff_call(_arg(x), y)
Base.:-(x, y::Call) = _diff_call(x, _arg(y))
Base.:-(x::Call, y::Call) = _diff_call(_arg(x), _arg(y))

function _diff_call(x, y)
    if iszero(y)
        Call(x)
    elseif iszero(x)
        Call(-y)
    elseif x == y
        Call(0.0)
    else
        Call(-, [x, y])
    end
end

Base.:*(ts::TimeSeries, num::Number) = timedata_operation(*, ts, num)
Base.:*(num::Number, ts::TimeSeries) = timedata_operation(*, num, ts)
Base.:*(tp::TimePattern, num::Number) = timedata_operation(*, tp, num)
Base.:*(num::Number, tp::TimePattern) = timedata_operation(*, num, tp)
Base.:*(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(*, ts1, ts2)
Base.:*(ts::TimeSeries, tp::TimePattern) = timedata_operation(*, ts, tp)
Base.:*(tp::TimePattern, ts::TimeSeries) = timedata_operation(*, tp, ts)
Base.:*(tp1::TimePattern, tp2::TimePattern) = timedata_operation(*, tp1, tp2)
Base.:*(m::Map, x::Union{Number,TimeSeries,TimePattern}) = timedata_operation(*, m, x)
Base.:*(x::Union{Number,TimeSeries,TimePattern}, m::Map) = timedata_operation(*, x, m)
Base.:*(m1::Map, m2::Map) = timedata_operation(*, m1, m2)
Base.:*(x::Call, y) = _prod_call([_args(*, x); y])
Base.:*(x, y::Call) = _prod_call([x; _args(*, y)])
Base.:*(x::Call, y::Call) = _prod_call([_args(*, x); _args(*, y)])

function _prod_call(args)
    numerical_args = filter(x -> x isa Number, args)
    non_numerical_args = filter(x -> !(x isa Number), args)
    numerical_factor = reduce(*, numerical_args; init=1.0)
    if isempty(non_numerical_args)
        Call(numerical_factor)
    elseif iszero(numerical_factor)
        Call(0.0)
    else
        final_args = non_numerical_args
        if !isone(numerical_factor) && !isone(-numerical_factor)
            push!(final_args, numerical_factor)
        end
        result = if length(final_args) == 1
            Call(final_args[1])
        else
            Call(*, final_args)
        end
        if isone(-numerical_factor)
            -result
        else
            result
        end
    end
end

Base.:/(ts::TimeSeries, num::Number) = timedata_operation(/, ts, num)
Base.:/(num::Number, ts::TimeSeries) = timedata_operation(/, num, ts)
Base.:/(tp::TimePattern, num::Number) = timedata_operation(/, tp, num)
Base.:/(num::Number, tp::TimePattern) = timedata_operation(/, num, tp)
Base.:/(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(/, ts1, ts2)
Base.:/(ts::TimeSeries, tp::TimePattern) = timedata_operation(/, ts, tp)
Base.:/(tp::TimePattern, ts::TimeSeries) = timedata_operation(/, tp, ts)
Base.:/(tp1::TimePattern, tp2::TimePattern) = timedata_operation(/, tp1, tp2)
Base.:/(m::Map, x::Union{Number,TimeSeries,TimePattern}) = timedata_operation(/, m, x)
Base.:/(x::Union{Number,TimeSeries,TimePattern}, m::Map) = timedata_operation(/, x, m)
Base.:/(m1::Map, m2::Map) = timedata_operation(/, m1, m2)
Base.:/(x::Call, y) = _ratio_call(_arg(x), y)
Base.:/(x, y::Call) = _ratio_call(x, _arg(y))
Base.:/(x::Call, y::Call) = _ratio_call(_arg(x), _arg(y))

function _ratio_call(x, y)
    if iszero(x)
        Call(0.0)
    elseif isone(y)
        Call(x)
    elseif x == y
        Call(1.0)
    else
        Call(/, [x, y])
    end
end

Base.:^(ts::TimeSeries, num::Number) = timedata_operation(^, ts, num)
Base.:^(num::Number, ts::TimeSeries) = timedata_operation(^, num, ts)
Base.:^(tp::TimePattern, num::Number) = timedata_operation(^, tp, num)
Base.:^(num::Number, tp::TimePattern) = timedata_operation(^, num, tp)
Base.:^(ts1::TimeSeries, ts2::TimeSeries) = timedata_operation(^, ts1, ts2)
Base.:^(ts::TimeSeries, tp::TimePattern) = timedata_operation(^, ts, tp)
Base.:^(tp::TimePattern, ts::TimeSeries) = timedata_operation(^, tp, ts)
Base.:^(tp1::TimePattern, tp2::TimePattern) = timedata_operation(^, tp1, tp2)
Base.:^(m::Map, x::Union{Number,TimeSeries,TimePattern}) = timedata_operation(^, m, x)
Base.:^(x::Union{Number,TimeSeries,TimePattern}, m::Map) = timedata_operation(^, x, m)
Base.:^(m1::Map, m2::Map) = timedata_operation(^, m1, m2)

Base.min(x::Call, y::Call) = Call(min, [x, y])
Base.min(x::Call, y) = Call(min, [x, y])
Base.min(x, y::Call) = Call(min, [x, y])

Base.max(x::Call, y::Call) = Call(max, [x, y])
Base.max(x::Call, y) = Call(max, [x, y])
Base.max(x, y::Call) = Call(max, [x, y])

_arg(x::Call) = _arg(x.func, x)
_arg(::Nothing, x) = x.args[1]
_arg(::T, x) where T = x

_args(op, x::Call) = _args(op, x.func, x)
_args(op, ::Nothing, x) = x.args[1]
_args(op, ::T, x) where T<:Union{ParameterValue,Function} = x
_args(op::T, ::T, x) where T<:Function = x.args

Base.values(ts::TimeSeries) = ts.values
Base.values(m::Map) = m.values
Base.values(pv::ParameterValue{T}) where {T<:_Indexed} = values(pv.value)

Base.keys(ts::TimeSeries) = ts.indexes
Base.keys(m::Map) = m.indexes
Base.keys(pv::ParameterValue{T}) where {T<:_Indexed} = keys(pv.value)

function Base.merge!(a::TimeSeries, b::TimeSeries)
    for (b_index, b_value) in b
        a[b_index] = b_value
    end
    a
end
function Base.merge!(a::Map, b::Map)
    for (b_index, b_value) in b
        a_value = get(a, b_index, nothing)
        if _can_merge(a_value, b_value)
            merge!(a_value, b_value)
        else
            a[b_index] = b_value
        end
    end
    a
end
function Base.merge!(a::ParameterValue, b::ParameterValue)
    merge!(a.value, b.value)
    _refresh_metadata!(a)
    a
end

_can_merge(a::TimePattern, b::TimePattern) = true
_can_merge(a::TimeSeries, b::TimeSeries) = true
_can_merge(a::Map, b::Map) = true
_can_merge(a, b) = false
_can_merge(a::ParameterValue, b::ParameterValue) = _can_merge(a.value, b.value)

function Base.push!(x::Union{TimeSeries,Map}, pair)
    index, value = pair
    i = searchsortedfirst(x.indexes, index)
    if get(x.indexes, i, nothing) == index
        x.values[i] = value
    else
        insert!(x.indexes, i, index)
        insert!(x.values, i, value)
    end
    x
end

function Base.setindex!(x::Union{TimeSeries,Map}, value, key...)
    length(key) > 1 && error("invalid index $key")
    push!(x, first(key) => value)
    value
end

_searchsortedfirst(indexes::Vector{T}, key::T) where T = searchsortedfirst(indexes, key)
_searchsortedfirst(indexes, key) = 0

function Base.get(x::Union{TimeSeries,Map}, key, default)
    i = _searchsortedfirst(x.indexes, key)
    get(x.indexes, i, nothing) == key ? x.values[i] : default
end

function Base.getindex(x::Union{TimeSeries,Map}, key)
    i = _searchsortedfirst(x.indexes, key)
    if get(x.indexes, i, nothing) == key
        x.values[i]
    else
        throw(BoundsError(x, key))
    end
end
# Override `getindex` for `Parameter` so we can call `parameter[...]` and get a `Call`
Base.getindex(p::Parameter, inds::NamedTuple) = _getindex(p; inds...)
function _getindex(p::Parameter; _strict=true, _default=nothing, kwargs...)
    call_expr = (p.name, (; kwargs...))
    pv_new_kwargs = _split_parameter_value_kwargs(p; _strict=_strict, _default=_default, kwargs...)
    if pv_new_kwargs !== nothing
        parameter_value, new_inds = pv_new_kwargs
        Call(parameter_value, new_inds, call_expr)
    else
        Call(nothing, call_expr)
    end
end

function Base.get!(x::Union{TimeSeries,Map}, key, default)
    get!(x, key) do
        default
    end
end
function Base.get!(f::Function, x::Union{TimeSeries,Map}, key)
    i = searchsortedfirst(x.indexes, key)
    if get(x.indexes, i, nothing) == key
        x.values[i]
    elseif i > lastindex(x.indexes)
        val = f()
        push!(x.indexes, key)
        push!(x.values, val)
        val
    else
        x.values[i] = f()
    end
end

Base.iszero(x::Union{TimeSeries,TimePattern}) = iszero(values(x))
Base.isapprox(x::Union{TimeSeries,TimePattern}, y; kwargs...) = all(isapprox(v, y; kwargs...) for v in values(x))
Base.isapprox(x::ParameterValue, y; kwargs...) = isapprox(x(), y; kwargs...)

function Base.getproperty(pv::ParameterValue, name::Symbol)
    if name === :value
        getfield(pv, name)
    elseif name !== :metadata
        pv.metadata[name]
    else
        getfield(pv, name)
    end
end

# Patches: these just work-around `MethodError`s, but we should try something more consistent
Base.abs(call::Call) = Call(abs, [call])

Base.isempty(x::Union{TimeSeries,Map}) = isempty(x.indexes)

function Base.empty!(x::ParameterValue{T}) where {T<:_Indexed}
    empty!(x.value)
    empty!(x.metadata)
end
function Base.empty!(x::Union{TimeSeries,Map})
    empty!(x.indexes)
    empty!(x.values)
end