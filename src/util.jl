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
    indices(p::Parameter; value_filter=x->x!=nothing, kwargs...)

A set of indices corresponding to `p`, optionally filtered by `kwargs`.
"""
# If a dimension is not specified, get all of them. Eg. unit but no mode, get all modes for the unit
# But also ignore irrelevant dimensions specified. Eg. constraint, get all
function indices(p::Parameter; value_filter=x->x!=nothing, kwargs...)
    d = p.class_value_dict
    new_kwargs = Dict()
    for (obj_cls, obj) in kwargs
        if obj != anything
            push!(new_kwargs, obj_cls => Object.(obj))
        end
    end
    result = []
    for (key, value) in d
        iargs = Dict(i => new_kwargs[k] for (i, k) in enumerate(key) if k in keys(new_kwargs))
        append!(
            result,
            NamedTuple{key}(ind) for (ind, val) in value if all(ind[i] in v for (i, v) in iargs) && value_filter(val())
        )
    end
    result
end
