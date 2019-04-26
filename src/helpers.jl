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
    parse_value(db_value; default=nothing, tags...)

Parse a database value into a value to be returned by the parameter access function.
The default value is passed in the `default` argument, and tags are passed in the `tags...` argument
Add methods to this function to customize the way you access parameters in your database.
"""
parse_value(db_value; default=nothing, tags...) = db_value

function parse_value(db_value::Nothing; default=nothing, tags...)
    if default === nothing
        nothing
    else
        parse_value(default; default=nothing, tags...)
    end
end

function parse_value(db_value::String; default=nothing, tags...)
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

parse_value(db_value::Array; default=nothing, tags...) = [parse_value(x; default=default, tags...) for x in db_value]

function parse_value(db_value::Dict; default=nothing, tags...)
    Dict(parse_value(k; default=default, tags...) => v for (k, v) in db_value)
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

"""
    getsubkey(dict::Dict{Tuple,T}, key::Tuple, default)

Return the first key which has all the elements in the tuple argument `key`, if one exists in `dict`,
otherwise return `default`.
"""
function getsubkey(dict::Dict{Tuple,T}, key::Tuple, default) where T
    issubkey(subkey) = all(k in key for k in subkey)
    collected_keys = collect(keys(dict))
    i = findfirst(issubkey, collected_keys)
    if i === nothing
        default
    else
        collected_keys[i]
    end
end
