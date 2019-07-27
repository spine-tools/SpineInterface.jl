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

A set of indices corresponding to `p`, optionally filtered by `kwargs`.
"""
function indices(p::Parameter; kwargs...)
    result = []
    for class_ in p.classes
        class = getfield(p.mod, class_)
        append!(
            result,
            [
                relationship
                for (relationship, values) in lookup(class; kwargs...)
                if get(values, p.name, class.default_values[p.name])() != nothing
            ]
        )
    end
    result
end

"""
    to_database(x)

A JSON representation of `x` to go in a Spine database.
"""
to_database(x::Union{DateTime_,DurationLike,TimePattern,TimeSeries}) = PyObject(x).to_database()
