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
    parse_value(db_value; default, tags...)

Parse a json value from a Spine database into a user defined function-like object.
This object will be called when accessing the parameter.
The default value is passed in the `default` argument, and tags are passed in the `tags...` argument
"""
function parse_value(db_value::Nothing; default=nothing, tags...)
    if default === nothing
        NoValue()
    else
        parse_value(default; default=nothing, tags...)
    end
end

parse_value(db_value::Int64; kwargs...) = ScalarValue(db_value)
parse_value(db_value::Float64; kwargs...) = ScalarValue(db_value)
parse_value(db_value::String; kwargs...) = ScalarValue(Symbol(db_value))
parse_value(db_value::Array; kwargs...) = ArrayValue(db_value)
parse_value(db_value::Dict; kwargs...) = DictValue(db_value)
