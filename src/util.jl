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
"""
    indices(p::Parameter; kwargs...)

An array of all objects and relationships where the value of `p` is different than `nothing`.

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

julia> indices(tax_net_flow)
1-element Array{Any,1}:
 (commodity = water, node = Sthlm)

julia> indices(demand)
5-element Array{Any,1}:
 Nimes
 Sthlm
 Leuven
 Espoo
 Dublin

```
"""
function indices(p::Parameter; kwargs...)
    result = []
    if isempty(kwargs)
        for class in p.classes
            appendix = []
            sizehint!(appendix, length(class.values))
            for (ind, value) in enumerate(class.values)
                val = get(value, p.name) do
                    class.default_values[p.name]
                end
                val() === nothing || push!(appendix, entities(class)[ind])
            end
            append!(result, appendix)
        end
    else
        for class in p.classes
            inds = lookup(class; kwargs...)
            isempty(inds) && continue
            appendix = []
            sizehint!(appendix, length(inds))
            for ind in inds
                val = get(class.values[ind], p.name) do
                    class.default_values[p.name]
                end
                val() === nothing || push!(appendix, entities(class)[ind])
            end
            append!(result, appendix)
        end
    end
    result
end

"""
    to_database(x)

A JSON representation of `x` to go in a Spine database.
"""
to_database(x::Union{DateTime_,DurationLike,TimePattern,TimeSeries}) = PyObject(x).to_database()
