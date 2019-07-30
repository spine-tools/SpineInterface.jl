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
    fix_name_ambiguity(object_class_name_list)

Take `object_class_name_list`, and return a new list where repeated entries are distinguished by
appending an increasing integer.

# Example
```julia
julia> fix_name_ambiguity(["connection", "node", "node"])
3-element Array{String,1}:
 "connection"
 "node1"
 "node2"
```
"""
function fix_name_ambiguity(object_class_name_list::Array{T,1}) where T
    fixed = Array{T,1}()
    object_class_name_ocurrences = Dict{T,Int64}()
    for (i, object_class_name) in enumerate(object_class_name_list)
        n_ocurrences = count(x -> x == object_class_name, object_class_name_list)
        if n_ocurrences == 1
            push!(fixed, object_class_name)
        else
            ocurrence = get(object_class_name_ocurrences, object_class_name, 1)
            push!(fixed, string(object_class_name, ocurrence))
            object_class_name_ocurrences[object_class_name] = ocurrence + 1
        end
    end
    fixed
end

"""
    pull!(cache::Array{Pair,1}, lookup_key, default)
"""
function pull!(cache::Array{Pair,1}, lookup_key, default)
    i = 1
    found = false
    for (key, value) in cache
        if key == lookup_key
            found = true
            break
        end
        i += 1
    end
    if !found
        default
    else
        key, value = cache[i]
        if i > 32
            deleteat!(cache, i)
            pushfirst!(cache, key => value)
        end
        value
    end
end


"""
    uniquesorted(itr)

Like `unique`, but assuming `itr` is sorted. Result is undefined if `itr` is not sorted.
"""
function uniquesorted(itr)
    isempty(itr) && return []
    coll = collect(itr)
    [coll[1]; [coll[i] for i in 2:length(coll) if coll[i] != coll[i - 1]]]
end
