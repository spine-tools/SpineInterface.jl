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


struct TimePattern
    y::Union{Array{UnitRange{Int64},1},Nothing}
    m::Union{Array{UnitRange{Int64},1},Nothing}
    d::Union{Array{UnitRange{Int64},1},Nothing}
    wd::Union{Array{UnitRange{Int64},1},Nothing}
    H::Union{Array{UnitRange{Int64},1},Nothing}
    M::Union{Array{UnitRange{Int64},1},Nothing}
    S::Union{Array{UnitRange{Int64},1},Nothing}
    TimePattern(;y=nothing, m=nothing, d=nothing, wd=nothing, H=nothing, M=nothing, S=nothing) = new(y, m, d, wd, H, M, S)
end


function Base.show(io::IO, time_pattern::TimePattern)
    d = Dict{Symbol,String}(
        :y => "year",
        :m => "month",
        :d => "day",
        :wd => "day of the week",
        :H => "hour",
        :M => "minute",
        :S => "second",
    )
    ranges = Array{String,1}()
    for field in fieldnames(TimePattern)
        value = getfield(time_pattern, field)
        if value != nothing
            str = "$(d[field]) from "
            str *= join(["$(x.start) to $(x.stop)" for x in value], ", or ")
            push!(ranges, str)
        end
    end
    print(io, join(ranges, ",\nand "))
end


matches(time_pattern::TimePattern, str::String) = matches(time_pattern, parse_date_time_str(str))


"""
    matches(time_pattern::TimePattern, t::DateTime)

true if `time_pattern` matches `t`, false otherwise.
For every range specified in `time_pattern`, `t` has to be in that range.
If a range is not specified for a given level, then it doesn't matter where
(or should I say, *when*?) is `t` on that level.
"""
function matches(time_pattern::TimePattern, t::DateTime)
    conds = Array{Bool,1}()
    time_pattern.y != nothing && push!(conds, any(year(t) in rng for rng in time_pattern.y))
    time_pattern.m != nothing && push!(conds, any(month(t) in rng for rng in time_pattern.m))
    time_pattern.d != nothing && push!(conds, any(day(t) in rng for rng in time_pattern.d))
    time_pattern.wd != nothing && push!(conds, any(dayofweek(t) in rng for rng in time_pattern.wd))
    time_pattern.H != nothing && push!(conds, any(hour(t) in rng for rng in time_pattern.H))
    time_pattern.M != nothing && push!(conds, any(minute(t) in rng for rng in time_pattern.M))
    time_pattern.S != nothing && push!(conds, any(second(t) in rng for rng in time_pattern.S))
    all(conds)
end


function parse_date_time_str(str::String)
    reg_exp = r"[ymdHMS]"
    keys = [m.match for m in eachmatch(reg_exp, str)]
    values = split(str, reg_exp; keepempty=false)
    periods = Array{Period,1}()
    for (k, v) in zip(keys, values)
        k == "y" && push!(periods, Year(v))
        k == "m" && push!(periods, Month(v))
        k == "d" && push!(periods, Day(v))
        k == "H" && push!(periods, Hour(v))
        k == "M" && push!(periods, Minute(v))
        k == "S" && push!(periods, Second(v))
    end
    DateTime(periods...)
end


function parse_time_pattern(spec::String)
    union_op = ","
    intersection_op = ";"
    range_op = "-"
    kwargs = Dict()
    regexp = r"(y|m|d|wd|H|M|S)"
    pattern_specs = split(spec, union_op)
    for pattern_spec in pattern_specs
        range_specs = split(pattern_spec, intersection_op)
        for range_spec in range_specs
            m = match(regexp, range_spec)
            m === nothing && error("""invalid interval specification $range_spec.""")
            key = m.match
            start_stop = range_spec[length(key)+1:end]
            start_stop = split(start_stop, range_op)
            length(start_stop) != 2 && error("""invalid interval specification $range_spec.""")
            start_str, stop_str = start_stop
            start = try
                parse(Int64, start_str)
            catch ArgumentError
                error("""invalid lower bound $start_str.""")
            end
            stop = try
                parse(Int64, stop_str)
            catch ArgumentError
                error("""invalid upper bound $stop_str.""")
            end
            start > stop && error("""lower bound can't be higher than upper bound.""")
            arr = get!(kwargs, Symbol(key), Array{UnitRange{Int64},1}())
            push!(arr, range(start, stop=stop))
        end
    end
    TimePattern(;kwargs...)
end


"""
    parse_string(value::String)
"""
function parse_string(value::String)
    try
        parse(Int64, value)
    catch
        try
            parse(Float64, value)
        catch
            Symbol(value)
        end
    end
end


"""
    parse_value(value)
"""
function parse_value(value)
    parsed = JSON.parse(value)  # Let LoadError be thrown
    if parsed isa String
        try
            parse_time_pattern(parsed)
        catch e
            parse_string(parsed)
        end
    elseif parsed isa Dict
        # Advance work for the convenience function
        haskey(parsed, "type") || error("'type' missing")
        type_ = parsed["type"]
        if type_ == "time_pattern"
            haskey(parsed, "data") || error("'data' missing")
            parsed["data"] isa Dict || error("'data' should be a dictionary (time_pattern: value)")
            parsed["time_pattern_data"] = Dict{Union{TimePattern,String},Any}()
            # Try and parse String keys as TimePatterns into a new dictionary
            for (k, v) in pop!(parsed, "data")
                new_k = try
                    parse_time_pattern(k)
                catch e
                    k
                end
                parsed["time_pattern_data"][new_k] = v
            end
            parsed
        else
            error("unknown type '$type_'")
        end
    else
        parsed
    end
end


"""
A scalar corresponding to index `t` in `value`.
Called by convenience functions for returning parameter values.

- If `value` is an `Array`, then the result is position `t` in the `Array`.
- If `value` is a `Dict`, then:
  - If `value["type"]` is "time_pattern", then the result is one of the values
    from `value["time_pattern_data"]` that matches `t`.
  - More to come...
- If `value` is a `TimePattern`, then:
  - If `t` is `nothing`, then the result is `value` itself.
  - It `t` is not `nothing`, then the result is `true` or `false` depending on whether or not `value` matches `t`.
- If `value` is a scalar, then the result is `value` itself
"""
function get_scalar(value::Any, t::Union{Int64,String,Nothing})
    if value isa Array
        t === nothing && error("argument `t` missing")
        return value[t]
    elseif value isa Dict
        # Fun begins
        # NOTE: At this point we shouldn't be afraid of accessing keys or whatever,
        # since everything was validated before
        type_ = value["type"]
        if type_ == "time_pattern"
            t === nothing && error("argument `t` missing")
            time_pattern_data = value["time_pattern_data"]
            for (k, v) in time_pattern_data
                time_pattern = if k isa TimePattern
                    k
                else
                    try
                        eval(Symbol(k))()
                    catch e
                        if e isa UndefVarError
                            error("unknown time pattern '$k'")
                        else
                            rethrow()
                        end
                    end
                end
                matches(time_pattern, t) && return v
            end
            error("'$t' does not match any time pattern")
        else
            error("unknown type '$type_'")
        end
    elseif value isa TimePattern
        if t != nothing
            return matches(value, t)
        else
            return value
        end
    else
        return value
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
