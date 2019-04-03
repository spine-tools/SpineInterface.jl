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
    parse_value(db_value, tag_list)

"""
function parse_value(db_value::String, tag_list)
    try
        parse(Int64, db_value)
    catch
        try
            parse(Float64, db_value)
        catch
            Symbol(db_value)
        end
    end
end


parse_value(db_value, tag_list) = db_value


"""
    get_value(value, t=nothing)

"""
function get_value(value, t=nothing)
    if isimmutable(value)
        value
    else
        value[t]
    end
end


function diff_database_mapping(url::String; upgrade=false)
    try
        db_api.DiffDatabaseMapping(url, "SpineInterface.jl"; upgrade=upgrade)
    catch e
        if isa(e, PyCall.PyError) && pyisinstance(e.val, db_api.exception.SpineDBVersionError)
            error(
"""
The database at '$(url)' is from an older version of Spine
and needs to be upgraded in order to be used with the current version.

You can upgrade by passing the keyword argument `upgrade=true` to your function call, e.g.:

    diff_database_mapping(url; upgrade=true)

WARNING: After the upgrade, the database may no longer be used
with previous versions of Spine.
"""
            )
        else
            rethrow()
        end
    end
end


"""
    fix_name_ambiguity(object_class_name_list)

A list identical to `object_class_name_list`, except that repeated entries are modified by
appending an increasing integer.

# Example
```julia
julia> s=[:connection, :node, :node]
3-element Array{Symbol,1}:
 :connection
 :node
 :node

julia> fix_name_ambiguity(s)
3-element Array{Symbol,1}:
 :connection
 :node1
 :node2
```
"""
function fix_name_ambiguity(object_class_name_list::Array{Symbol,1})
    fixed = Array{Symbol,1}()
    object_class_name_ocurrences = Dict{Symbol,Int64}()
    for (i, object_class_name) in enumerate(object_class_name_list)
        n_ocurrences = count(x -> x == object_class_name, object_class_name_list)
        if n_ocurrences == 1
            push!(fixed, object_class_name)
        else
            ocurrence = get(object_class_name_ocurrences, object_class_name, 1)
            push!(fixed, Symbol(object_class_name, ocurrence))
            object_class_name_ocurrences[object_class_name] = ocurrence + 1
        end
    end
    fixed
end
