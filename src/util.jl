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
function indices(p::Parameter; value=x->x!=nothing, kwargs...)
    d = p.class_value_dict
    if !isempty(kwargs)
        key_list = getsuperkeys(d, keys(kwargs))
        result = [NamedTuple{key}(ind) for key in key_list for (ind, val) in d[key] if value(val())] # != NoValue()]
        new_kwargs = Dict()
        for (obj_cls, obj) in kwargs
            if obj != anything
                push!(new_kwargs, obj_cls => Object.(obj))
            end
        end
        [x for x in result if all(x[obj_cls] in obj for (obj_cls, obj) in new_kwargs)]
    else
        result = [NamedTuple{key}(ind) for key in keys(d) for (ind, val) in d[key] if value(val())] # != NoValue()]
    end
end
