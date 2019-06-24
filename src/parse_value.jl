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
    parse_value(db_value; default=nothing)

A function-like object for accessing a parameter value. `db_value` is the Julia equivalent of
the JSON value from the `value` field of the `parameter_value` table.
The default value is passed in the `default` argument
"""
function parse_value(db_value::Nothing; default=nothing)
    if default === nothing
        NoValue()
    else
        parse_value(default; default=nothing)
    end
end

parse_value(db_value::Bool; default=nothing) = ScalarValue(db_value)
parse_value(db_value::Int64; default=nothing) = ScalarValue(db_value)
parse_value(db_value::Float64; default=nothing) = ScalarValue(db_value)
parse_value(db_value::String; default=nothing) = ScalarValue(db_value)
parse_value(db_value::Array; default=nothing) = ArrayValue(parse_value.(db_value))

function parse_value(db_value::Dict; default=nothing)
    type = get(db_value, "type", nothing)
    if type == "date_time"
        ScalarValue(parse_date_time(db_value["data"]))
    elseif type == "duration"
        ScalarValue(parse_duration(db_value["data"]))
    elseif type == "time_pattern"
        TimePatternValue(Dict(TimePattern(k) => v for (k, v) in db_value["data"]), default)
    elseif type == "time_series"
        index = get(db_value, "index", Dict())
        TimeSeriesValue(db_value["data"], index, default)
    else
        DictValue(k => parse_value(v) for (k, v) in db_value)
    end
end

# const iso8601 = dateformat"yyyy-mm-ddTHH:MMz"
const iso8601zoneless = dateformat"yyyy-mm-ddTHH:MM"

function parse_date_time(value)
    DateTime(value, iso8601zoneless)
    # try
    #    ZonedDateTime(value, iso8601)
    # catch
    #    ZonedDateTime(DateTime(value, iso8601zoneless), tz"UTC")
    # end
end

"""
    parse_duration(str::String)

Parse the given string as a Period value.
"""
function parse_duration(str::String)
    split_str = split(str, " ")
    if length(split_str) == 1
        # Compact form, eg. "1D"
        number = str[1:end-1]
        time_unit = str[end]
        if lowercase(time_unit) == 'y'
            Year(number)
        elseif time_unit == 'm'
            Month(number)
        elseif time_unit == 'd'
            Day(number)
        elseif time_unit == 'H'
            Hour(number)
        elseif time_unit == 'M'
            Minute(number)
        elseif time_unit == 'S'
            Second(number)
        else
            error("invalid duration specification '$str'")
        end
    elseif length(split_str) == 2
        # Verbose form, eg. "1 day"
        number, time_unit = split_str
        time_unit = lowercase(time_unit)
        time_unit = endswith(time_unit, "s") ? time_unit[1:end-1] : time_unit
        if time_unit == "year"
            Year(number)
        elseif time_unit == "month"
            Month(number)
        elseif time_unit == "day"
            Day(number)
        elseif time_unit == "hour"
            Hour(number)
        elseif time_unit == "minute"
            Minute(number)
        elseif time_unit == "second"
            Second(number)
        else
            error("invalid duration specification '$str'")
        end
    else
        error("invalid duration specification '$str'")
    end
end

parse_duration(int::Int64) = Minute(int)
