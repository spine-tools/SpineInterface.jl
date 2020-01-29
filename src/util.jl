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

# Map iterator. It applies the given `map` function over elements of the given `itr`.
# Used by `indices`
struct Map{F,I}
    map::F
    itr::I
end

function Base.iterate(m::Map, state...)
    y = iterate(m.itr, state...)
    y === nothing && return nothing
    m.map(y[1]), y[2]
end

Base.eltype(::Type{Map{F,I}}) where {F,I} = eltype(I)
Base.IteratorEltype(::Type{Map{F,I}}) where {F,I} = Base.IteratorEltype(I)
Base.IteratorSize(::Type{Map{F,I}}) where {F,I} = Base.IteratorSize(I)


_lookup_entities(class::ObjectClass; kwargs...) = class()
_lookup_entities(class::RelationshipClass; kwargs...) = class(; _compact=false, kwargs...)

_entity_key(o::Object) = o
_entity_key(r::Relationship) = tuple(r...)

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
    itr = Iterators.flatten(
        Map(ent -> (ent, class.parameter_values[_entity_key(ent)]), _lookup_entities(class; kwargs...)) for class in p.classes
    )
    # Filtering function, `true` if the value is not nothing
    flt(x) = last(x)[p.name]() !== nothing
    Map(first, Iterators.filter(flt, itr))
end


# Time slice map
struct TimeSliceMap
    time_slices::Array{TimeSlice,1}
    index::Array{Int64,1}
end

function TimeSliceMap(time_slices::Array{TimeSlice,1})
    map_start = start(first(time_slices))
    map_end = end_(last(time_slices))
    index = Array{Int64,1}(undef, Minute(map_end - map_start).value)
    for (ind, t) in enumerate(time_slices)
        first_minute = Minute(start(t) - map_start).value + 1
        last_minute = Minute(end_(t) - map_start).value
        index[first_minute:last_minute] .= ind
    end
    TimeSliceMap(time_slices, index)
end

function (h::TimeSliceMap)(t::TimeSlice...)
    indices = Array{Int64,1}()
    map_start = start(first(h.time_slices))
    map_end = end_(last(h.time_slices))
    for s in t
        s_start = max(map_start, start(s))
        s_end = min(map_end, end_(s))
        s_end <= s_start && continue
        first_ind = h.index[Minute(s_start - map_start).value + 1]
        last_ind = h.index[Minute(s_end - map_start).value]
        append!(indices, collect(first_ind:last_ind))
    end
    unique(h.time_slices[ind] for ind in indices)
end
