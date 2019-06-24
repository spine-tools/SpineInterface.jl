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
struct NoValue
end

struct ScalarValue{T}
    value::T
end

struct ArrayValue
    value::Array
end

struct DictValue
    value::Dict
end

"""
    TimePattern(...)
"""
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

"""
    TimePattern(spec::String)

A `TimePattern` value parsed from the given string specification.
"""
function TimePattern(spec::String)
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

struct TimePatternValue
    dict::Dict{TimePattern,T} where T
    default
end

struct TimeSeriesValue{I,V,DV}
    time_stamps::I
    values::Array{V,1}
    default::DV
    ignore_year::Bool
    repeat::Bool
    span::Period
    mean_value::V
    function TimeSeriesValue(i::I, v::Array{V,1}, d::DV, iy=false, r=false) where {I,V,DV}
        if length(i) != length(v)
            error("lengths don't match")
        else
            if r
                # Compute span and mean value to save work when accessing repeating time series
                s = i[end] - i[1]
                mv = mean(v)
            else
                s = zero(Hour)
                mv = 0
            end
            new{I,V,DV}(i, v, d, iy, r, s, mv)
        end
    end
end

# Outer constructors
ScalarValue(s::String) = ScalarValue(Symbol(s))

ArrayValue(gen::T) where T <: Base.Generator = ArrayValue(collect(gen))
DictValue(gen::T) where T <: Base.Generator = DictValue(Dict(gen))

function TimeSeriesValue(data::Array, index::Dict, default)
    # Look at the first element in data to see whether it's one column or two column format (and pray)
    if data[1] isa Array
        # Two column array format
        TimeSeriesValue(Dict(k => v for (k, v) in data), index, default)
    else
        # One column array format
        if haskey(index, "start")
            start = parse_date_time(index["start"])
            ignore_year = get(index, "ignore_year", false)
            repeat = get(index, "repeat", false)
        else
            start = DateTime(1)
            ignore_year = get(index, "ignore_year", true)
            repeat = get(index, "repeat", true)
        end
        ignore_year && (start -= Year(start))
        len = length(data) - 1
        if haskey(index, "resolution")
            resolution = index["resolution"]
            if resolution isa Array
                rlen = length(resolution)
                if rlen > len
                    # Trunk
                    resolution = resolution[1:len]
                elseif rlen < len
                    # Repeat
                    ratio = div(len, rlen)
                    tail_len = len - ratio * rlen
                    tail = resolution[1:tail_len]
                    resolution = vcat(repeat(resolution, ratio), tail)
                end
                res = parse_duration.(resolution)
                inds = cumsum(vcat(start, res))
            else
                res = parse_duration(resolution)
                end_ = start + len * res
                inds = start:res:end_
            end
        else
            res = Hour(1)
            end_ = start + len * res
            inds = start:res:end_
        end
        TimeSeriesValue(inds, data, default, ignore_year, repeat)
    end
end

function TimeSeriesValue(data::Dict, index::Dict, default)
    # time_stamps come with data, so just look for "ignore_year" in index
    repeat = false
    ignore_year = get(index, "ignore_year", false)
    data = Dict(parse_date_time(k) => v for (k, v) in data)
    ignore_year && (data = Dict(k - Year(k) => v for (k, v) in data))
    data = sort(data)
    TimeSeriesValue(collect(keys(data)), collect(values(data)), default, ignore_year, repeat)
end

# Call operator
(p::NoValue)(;kwargs...) = nothing
(p::ScalarValue)(;kwargs...) = p.value

function (p::ArrayValue)(;i::Union{Int64,Nothing}=nothing)
    if i === nothing
        @warn("argument `i` missing, returning the whole array")
        p.value
    else
        p.value[i]
    end
end

function (p::DictValue)(;k::Union{T,Nothing}=nothing) where T
    if k === nothing
        @warn("argument `k` missing, returning the whole dictionary")
        p.value
    else
        p.value[t]
    end
end


"""
    match(ts::TimeSlice, tp::TimePattern)

Test whether a time slice matches a time pattern.
A time pattern and a time series match iff, for every time level (year, month, and so on),
the time slice fully contains at least one of the ranges specified in the time pattern for that level.
"""
function match(ts::TimeSlice, tp::TimePattern)
    conds = Array{Bool,1}()
    tp.y != nothing && push!(conds, any(range_in(rng, year(ts.start):year(ts.end_)) for rng in tp.y))
    tp.m != nothing && push!(conds, any(range_in(rng, month(ts.start):month(ts.end_)) for rng in tp.m))
    tp.d != nothing && push!(conds, any(range_in(rng, day(ts.start):day(ts.end_)) for rng in tp.d))
    tp.wd != nothing && push!(conds, any(range_in(rng, dayofweek(ts.start):dayofweek(ts.end_)) for rng in tp.wd))
    tp.H != nothing && push!(conds, any(range_in(rng, hour(ts.start):hour(ts.end_)) for rng in tp.H))
    tp.M != nothing && push!(conds, any(range_in(rng, minute(ts.start):minute(ts.end_)) for rng in tp.M))
    tp.S != nothing && push!(conds, any(range_in(rng, second(ts.start):second(ts.end_)) for rng in tp.S))
    all(conds)
end

"""
    range_in(b::UnitRange{Int64}, a::UnitRange{Int64})

Test whether `b` is fully contained in `a`.
"""
range_in(b::UnitRange{Int64}, a::UnitRange{Int64}) = b.start >= a.start && b.stop <= a.stop

function (p::TimePatternValue)(;t::Union{TimeSlice,Nothing}=nothing)
    t === nothing && error("argument `t` missing")
    values = [val for (tp, val) in p.dict if match(t, tp)]
    if isempty(values)
        @warn("$t does not match $p, using default value...")
        p.default
    else
        mean(values)
    end
end

function (p::TimeSeriesValue)(;t::Union{TimeSlice,Nothing}=nothing)
    t === nothing && return p
    start = t.start
    end_ = t.end_
    duration = t.duration
    if p.ignore_year
        start -= Year(start)
        end_ = start + duration
    end
    if p.repeat
        repetitions = 0
        if start > p.time_stamps[end]
            # Move start back within time_stamps range
            mismatch = start - p.time_stamps[1]
            repetitions = div(mismatch, p.span)
            start -= repetitions * p.span
            end_ = start + duration
        end
        if end_ > p.time_stamps[end]
            # Move end_ back within time_stamps range
            mismatch = end_ - p.time_stamps[1]
            repetitions = div(mismatch, p.span)
            end_ -= repetitions * p.span
        end
        a = findfirst(i -> i >= start, p.time_stamps)
        b = findlast(i -> i < end_, p.time_stamps)
        if a === nothing || b === nothing
            @warn("$p is not defined on $t, using default value...")
            p.default
        else
            if a <= b
                value = mean(p.values[a:b])
            else
                value = -mean(p.values[b:a])
            end
            value + repetitions * p.mean_value  # repetitions holds the number of rolls we move back the end
        end
    else
        a = findfirst(i -> i >= start, p.time_stamps)
        b = findlast(i -> i <= end_, p.time_stamps)
        if a === nothing || b === nothing
            @warn("$p is not defined on $t, using default value...")
            p.default
        else
            mean(p.values[a:b])
        end
    end
end

# Utility
time_stamps(val::TimeSeriesValue) = val.time_stamps

# Iterate single ScalarValue as collection
Base.iterate(v::ScalarValue) = iterate((v,))
Base.iterate(v::ScalarValue, state::T) where T = iterate((v,), state)
Base.length(v::ScalarValue) = 1
# Compare ScalarValue
Base.isless(v1::ScalarValue, v2::ScalarValue) = v1.value < v2.value
# Show ScalarValue
Base.show(io::IO, v::ScalarValue) = print(io, v.value)
