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

_next_id(id_factory::ObjectIdFactory) = id_factory.max_object_id[] += 1

_immutable(x) = x
_immutable(arr::T) where T<:AbstractArray = (length(arr) == 1) ? first(arr) : Tuple(arr)

function _lookup_callable(p::Parameter; kwargs...)
    for class in p.classes
        lookup_key = _lookup_key(class; kwargs...)
        parameter_values = get(class.parameter_values, lookup_key, nothing)
        parameter_values === nothing && continue
        return parameter_values[p.name]
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

_entity_key(o::Object) = o
_entity_key(r::Relationship) = tuple(r...)

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

function _lower_upper(h::TimeSeriesMap, t_start::DateTime, t_end::DateTime)
    (t_start > h.map_end || t_end <= h.map_start) && return ()
    t_start = max(t_start, h.map_start)
    t_end = min(t_end, h.map_end + Minute(1))
    lower = h.index[Minute(t_start - h.map_start).value + 1]
    upper = h.index[Minute(t_end - h.map_start).value + 1] - 1
    lower, upper
end

function _getproperty_or_default(m::Module, name::Symbol, default=nothing)
    (name in names(m; all=true)) ? getproperty(m, name) : default
end

(p::NothingCallable)(;kwargs...) = nothing
(p::ScalarCallable)(;kwargs...) = p.value

function (p::ArrayCallable)(;i::Union{Int64,Nothing}=nothing, kwargs...)
    i === nothing && return p.value
    get(p.value, i, nothing)
end

function (p::TimePatternCallable)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
    t === nothing && return p.value
    values = [val for (tp, val) in p.value if iscontained(t, tp)]
    if isempty(values)
        nothing
    else
        mean(values)
    end
end

function (p::StandardTimeSeriesCallable)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
    t === nothing && return p.value
    p.value.ignore_year && (t -= Year(start(t)))
    ab = _lower_upper(p.t_map, start(t), end_(t))
    isempty(ab) && return nothing
    a, b = ab
    a > b && return nothing
    mean(p.value.values[a:b])
end

function (p::RepeatingTimeSeriesCallable)(;t::Union{TimeSlice,Nothing}=nothing, kwargs...)
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
        (sum(p.value.values[a:b - 1]) + reps * p.valsum) / (b - a + reps * p.len)
    else
        div(
            sum(p.value.values[1:b]) + sum(p.value.values[a:end]) + (reps - 1) * p.valsum,
            b - a + 1 + reps * p.len
        )
    end
end