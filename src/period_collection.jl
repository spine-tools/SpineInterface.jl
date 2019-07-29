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
    PeriodCollection
"""
struct PeriodCollection
    Y::Union{Array{UnitRange{Int64},1},Nothing}
    M::Union{Array{UnitRange{Int64},1},Nothing}
    D::Union{Array{UnitRange{Int64},1},Nothing}
    WD::Union{Array{UnitRange{Int64},1},Nothing}
    h::Union{Array{UnitRange{Int64},1},Nothing}
    m::Union{Array{UnitRange{Int64},1},Nothing}
    s::Union{Array{UnitRange{Int64},1},Nothing}
    function PeriodCollection(;Y=nothing, M=nothing, D=nothing, WD=nothing, h=nothing, m=nothing, s=nothing)
        new(Y, M, D, WD, h, m, s)
    end
end

"""
    PeriodCollection(spec::String)

Construct a `PeriodCollection` from the given string specification.
"""
function PeriodCollection(spec::String)
    union_op = ","
    intersection_op = ";"
    range_op = "-"
    kwargs = Dict()
    regexp = r"(Y|M|D|WD|h|m|s)"
    for intervals in split(spec, union_op)
        for interval in split(intervals, intersection_op)
            m = Base.match(regexp, interval)
            m === nothing && error("invalid interval specification $interval.")
            key = m.match
            start_stop = interval[length(key)+1:end]
            start_stop = split(start_stop, range_op)
            length(start_stop) != 2 && error("invalid interval specification $interval.")
            start_str, stop_str = start_stop
            start = try
                parse(Int64, start_str)
            catch ArgumentError
                error("invalid lower bound $start_str.")
            end
            stop = try
                parse(Int64, stop_str)
            catch ArgumentError
                error("invalid upper bound $stop_str.")
            end
            start > stop && error("lower bound can't be higher than upper bound.")
            arr = get!(kwargs, Symbol(key), Array{UnitRange{Int64},1}())
            push!(arr, range(start, stop=stop))
        end
    end
    PeriodCollection(;kwargs...)
end


function Base.show(io::IO, period_collection::PeriodCollection)
    d = Dict{Symbol,String}(
        :Y => "year",
        :M => "month",
        :D => "day",
        :WD => "day of the week",
        :h => "hour",
        :m => "minute",
        :s => "second",
    )
    ranges = Array{String,1}()
    for field in fieldnames(PeriodCollection)
        value = getfield(period_collection, field)
        if value != nothing
            str = "$(d[field]) from "
            str *= join(["$(x.start) to $(x.stop)" for x in value], ", or ")
            push!(ranges, str)
        end
    end
    print(io, join(ranges, ",\nand "))
end
