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
    # Get iterators
    if isempty(kwargs)
        # No kwargs, just zip all entities and values
        itrs = (Iterators.zip(entities(class), class.values) for class in p.classes)
    else
        # Zip entities matching the kwargs, and their values
        itrs = (
            Map(i -> (entities(class)[i], class.values[i]), lookup_indices(class; kwargs...))
            for class in p.classes
        )
    end
    # Filtering function, `true` if the value is not nothing
    flt(x) = x[2][p.name]() !== nothing
    Map(first, Iterators.filter(flt, Iterators.flatten(itrs)))
end


"""
    append!(p::Parameter, values; kwargs...)

Append `values` to parameter `p`.

# Arguments

- For each object class associated with `p` there is a keyword argument named after it.
  The purpose is to retrieve the value of `p` for a specific object.
- For each relationship class associated with `p`, there is a keyword argument named after each of the
  object classes involved in it. The purpose is to retrieve the value of `p` for a specific relationship.

"""
function Base.append!(p::Parameter, values; _optimize=true, kwargs...)
    callable = lookup_callable(p; _optimize=_optimize, kwargs...)
    callable isa TimeSeriesCallableLike || return
    append!(callable.value, values)
    p
end


