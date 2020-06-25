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

function _getproperty_or_default(m::Module, name::Symbol, default=nothing)
    (name in names(m; all=true)) ? getproperty(m, name) : default
end

_next_id(id_factory::ObjectIdFactory) = id_factory.max_object_id[] += 1

_immutable(x) = x
_immutable(arr::T) where T<:AbstractArray = (length(arr) == 1) ? first(arr) : Tuple(arr)

function _get(d1, key, d2)
    get(d1, key) do
        d2[key]
    end
end

function _lookup_parameter_value(p::Parameter; kwargs...)
    for class in p.classes
        lookup_key = _lookup_key(class; kwargs...)
        parameter_values = get(class.parameter_values, lookup_key, nothing)
        parameter_values === nothing && continue
        return _get(parameter_values, p.name, class.parameter_defaults)
    end
end

_lookup_key(class::ObjectClass; kwargs...) = get(kwargs, class.name, nothing)
function _lookup_key(class::RelationshipClass; kwargs...)
    objects = Tuple(get(kwargs, oc, nothing) for oc in class.object_class_names)
    nothing in objects && return nothing
    objects
end

_lookup_entities(class::ObjectClass; kwargs...) = class()
_lookup_entities(class::RelationshipClass; kwargs...) = class(; _compact=false, kwargs...)

_entity_key(o::ObjectLike) = o
_entity_key(r::RelationshipLike) = tuple(r...)

function _relativedelta_to_period(delta::PyObject)
    # Add up till the day level
    minutes = delta.minutes + 60 * (delta.hours + 24 * delta.days)
    if minutes > 0
        # No way the `relativedelta` implementation added beyond this point
        Minute(minutes)
    else
        months = delta.months + 12 * delta.years
        Month(months)
    end
end

function _from_to_minute(m_start::DateTime, t_start::DateTime, t_end::DateTime)
    Minute(t_start - m_start).value + 1, Minute(t_end - m_start).value
end

(p::NothingParameterValue)(;kwargs...) = nothing

(p::ScalarParameterValue)(;kwargs...) = p.value

function (p::ArrayParameterValue)(;i::Union{Int64,Nothing}=nothing, kwargs...)
    i === nothing && return p.value
    get(p.value, i, nothing)
end

function (p::TimePatternParameterValue)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
    t === nothing && return p.value
    vals = [val for (tp, val) in p.value if overlaps(t, tp)]
    if isempty(vals)
        nothing
    else
        mean(vals)
    end
end

function _lower_upper(h::TimeSeriesMap, t_start::DateTime, t_end::DateTime)
    (t_start > h.map_end || t_end <= h.map_start) && return ()
    t_start = max(t_start, h.map_start)
    t_end = min(t_end, h.map_end + Minute(1))
    lower = h.index[Minute(t_start - h.map_start).value + 1]
    upper = h.index[Minute(t_end - h.map_start).value + 1] - 1
    lower, upper
end

function (p::StandardTimeSeriesParameterValue)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
    t === nothing && return p.value
    p.value.ignore_year && (t -= Year(start(t)))
    ab = _lower_upper(p.t_map, start(t), end_(t))
    isempty(ab) && return nothing
    a, b = ab
    a > b && return nothing
    mean(p.value.values[a:b])
end

function (p::RepeatingTimeSeriesParameterValue)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
    t === nothing && return p.value
    t_start = start(t)
    p.value.ignore_year && (t_start -= Year(t_start))
    if t_start > p.value.indexes[end]
        # Move t_start back within time_stamps range
        mismatch = t_start - p.value.indexes[1]
        reps = div(mismatch, p.span)
        t_start -= reps * p.span
    end
    t_end = t_start + (end_(t) - start(t))
    # Move t_end back within time_stamps range
    reps = if t_end > p.value.indexes[end]
        mismatch = t_end - p.value.indexes[1]
        div(mismatch, p.span)
    else
        0
    end
    t_end -= reps * p.span
    ab = _lower_upper(p.t_map, t_start, t_end)
    isempty(ab) && return nothing
    a, b = ab
    if a < b
        (sum(p.value.values[a:b]) + reps * p.valsum) / (b - a + 1 + reps * p.len)
    else
        div(
            sum(p.value.values[1:b]) + sum(p.value.values[a:end]) + (reps - 1) * p.valsum,
            b - a + 1 + reps * p.len
        )
    end
end

"""
    (p::MapParameterValue)(;inds=nothing, _strict=true, kwargs...)

Access `MapParameterValue` with the desired `inds`.

`inds` can be either a single index, or a Tuple of indices, in which case `MapParameterValue` calls itself
recursively. The recursive call is not `_strict`, meaning that if an index isn't found, the call still continues to
search for the remaining indices instead of returning `nothing`.
"""
function (p::MapParameterValue)(;inds=nothing, _strict=true, kwargs...)
    inds === nothing && return p.value
    if inds isa Tuple 
        if length(inds) > 1
            pv = parameter_value(p(;inds=inds[1], _strict=false, kwargs...))
            return pv(;inds=inds[2:end], kwargs...)
        else
            inds = first(inds)
        end
    end
    i = findall(i -> i == inds, p.value.indexes)
    if isempty(i)
        if _strict
            return nothing
        else
            return p.value
        end
    end
    pv = parameter_value(p.value.values[first(i)])
    pv(;kwargs...)
end

function (x::_IsLowestResolution)(t::TimeSlice)
    if contains(x.ref, t)
        false
    else
        x.ref = t
        true
    end
end

function (x::_IsHighestResolution)(t::TimeSlice)
    if iscontained(x.ref, t)
        false
    else
        x.ref = t
        true
    end
end