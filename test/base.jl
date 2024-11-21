#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
#
# This file is part of SpineInterface.
#
# SpineInterface is free software: you can redistribute it and/or modify
# it under the terms of the GNU Lesser General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# SpineInterface is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU Lesser General Public License for more details.
#
# You should have received a copy of the GNU Lesser General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.
#############################################################################

@testset "base" begin
    # intersect
    @test intersect(anything, [1]) == [1]
    @test intersect(anything, [:Spine]) == [:Spine]
    @test intersect([1, 2, 3], anything) == [1, 2, 3]
    # in, iterate, length, isless
    @test "Spine" in anything
    @test [4, 5, 6] in anything
    Spine = Object(:Spine, :App)
    Julia = Object(:Julia, :Lang)
    @test [x for x in Spine] == [Spine]
    @test length(Spine) == 1
    @test Julia < Spine
    t1 = TimeSlice(DateTime(0), DateTime(1))
    t2 = TimeSlice(DateTime(1), DateTime(2))
    @test [x for x in t1] == [t1]
    @test length(t1) == 1
    @test t1 < t2
    p5 = parameter_value(5)
    p7 = parameter_value(7)
    @test [x for x in p5] == [p5]
    @test length(p7) == 1
    @test p5 < p7
    n = 10
    @test t1 < DateTime(1, 1, 1, 0, 0, 1)
    @test 4.2 < TimeSeries([DateTime(i) for i in 1:n], [4.2 + i for i in 1:n], false, false)
    @test TimeSeries([DateTime(i) for i in 1:n], [4.2 - i for i in 1:n], false, false) < 4.2
    @test t1 <= DateTime(1)
    @test t1 <= DateTime(1, 2)
    @test 4.2 <= TimeSeries([DateTime(i) for i in 0:n], [4.2 + i for i in 0:n], false, false)
    @test TimeSeries([DateTime(i) for i in 0:n], [4.2 - i for i in 0:n], false, false) <= 4.2
    @test TimeSeries([DateTime(i) for i in 1:n], [4.2 for i in 1:n], false, false) == 4.2
    @test 4.2 == TimeSeries([DateTime(i) for i in 1:n], [4.2 for i in 1:n], false, false)
    # hash?
    d = Dict(anything => nothing)
    @test d[anything] === nothing
    # show
    @test string(anything) === "anything"
    @test string(t1) === "0000-01-01T00:00~(52 weeks, 2 days)~>0001-01-01T00:00"
    @test string(p5) === "ParameterValue(5)"
    duck = ObjectClass(:duck, [])
    studio_duck = RelationshipClass(:studio_duck, [:studio, :duck], [])
    @test string(duck) === "duck"
    @test string(studio_duck) === "studio_duck"
    id_call = Call(13)
    op_call = Call(+, 2, 3)
    apero_time = parameter_value("apero_time")
    param_val_call = Call(apero_time, (scenario=:covid,), (:apero_time, (scenario=:covid,)))
    @test string(id_call) === "13"
    @test string(op_call) === "2 + 3"
    @test string(param_val_call) === "{apero_time(scenario=covid) = apero_time}"
    tp1 = SpineInterface.parse_time_period("Y1-5;M1-4,M6-9")
    @test string(tp1) === "year from 1 to 5, and month from 1 to 4, or month from 6 to 9"
    # convert
    call = convert(Call, 9)
    @test call isa Call
    @test realize(call) === 9
    # copy
    val = parameter_value(nothing)
    val_copy = copy(val)
    @test val_copy isa SpineInterface.ParameterValue{Nothing}
    @test val_copy() === nothing
    val = parameter_value(10)
    val_copy = copy(val)
    @test val_copy isa SpineInterface.ParameterValue{T} where T<:Integer
    @test val_copy() === 10
    val = parameter_value([4, 5, 6])
    val_copy = copy(val)
    @test val_copy isa SpineInterface.ParameterValue{T} where T<:Array
    @test val_copy(i=1) === 4
    @test val_copy(i=2) === 5
    @test val_copy(i=3) === 6
    val = parameter_value(Dict(tp1 => 14))
    val_copy = copy(val)
    @test val_copy isa SpineInterface.ParameterValue{T} where T<:TimePattern
    @test convert(Int64, val_copy(t=TimeSlice(DateTime(1), DateTime(4)))) === 14
    ts = TimeSeries([DateTime(4), DateTime(5)], [100, 8], false, false)
    val = parameter_value(ts)
    val_copy = copy(val)
    @test val_copy isa SpineInterface.ParameterValue{T} where T<:TimeSeries
    @test convert(Int64, val_copy(t=TimeSlice(DateTime(4), DateTime(5)))) === 100
    ts = TimeSeries([DateTime(4), DateTime(5)], [100, 8], false, true)
    val = parameter_value(ts)
    val_copy = copy(val)
    @test val_copy isa SpineInterface.ParameterValue{T} where T<:TimeSeries
    @test val_copy(t=TimeSlice(DateTime(6), DateTime(7))) === (200 + 8) / 3
    call_copy = copy(id_call)
    @test call_copy isa Call
    @test string(call_copy) === "13"
    call_copy = copy(op_call)
    @test call_copy isa Call
    @test string(call_copy) === "2 + 3"
    call_copy = copy(param_val_call)
    @test call_copy isa Call
    @test string(call_copy) === "{apero_time(scenario=covid) = apero_time}"
    # Call zero
    zero_call = zero(call)
    @test zero_call isa Call
    @test iszero(zero_call)
    @test iszero(realize(zero_call))
    # Call one
    one_call = one(call)
    @test one_call isa Call
    @test isone(one_call)
    @test isone(realize(one_call))
    # Call plus
    call = +one_call
    @test op_call isa Call
    @test convert(Int, realize(call)) === 1
    op_call = zero_call + one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 1
    op_call = zero_call + 1
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 1
    op_call = 0 + one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 1
    # Call minus
    call = -one_call
    @test op_call isa Call
    @test convert(Int, realize(call)) === -1
    op_call = zero_call - one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === -1
    op_call = 0 - one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === -1
    op_call = zero_call - 1
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === -1
    # Call times
    op_call = zero_call * one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    op_call = one_call * one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 1
    minus_one_call = -one_call
    op_call = one_call * minus_one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === -1
    op_call = 0 * one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    op_call = 1 * one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 1
    op_call = -1 * one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === -1
    op_call = zero_call * 1
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    # Call div
    op_call = zero_call / one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    op_call = 0 / one_call
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    op_call = zero_call / 1
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    # Call min
    op_call = min(zero_call, one_call)
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    op_call = min(0, one_call)
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    op_call = min(zero_call, 1)
    @test op_call isa Call
    @test convert(Int, realize(op_call)) === 0
    # Call abs
    abs_call = abs(Call(-5))
    @test abs_call isa Call
    @test realize(abs_call) === 5
    # Arithmetic TimeSeries, TimePattern, and Map
    ts1_vals = [1, 2, 4]
    ts1_dates = [DateTime(1, i) for i in ts1_vals]
    ts2_vals = [2, 3, 4]
    ts2_dates = [DateTime(1, i) for i in ts2_vals]
    ts1 = TimeSeries(ts1_dates, ts1_vals, false, false)
    ts1_repeat = TimeSeries(ts1_dates, ts1_vals, false, true)
    ts1_ignore_year = TimeSeries(ts1_dates .- Year(DateTime(1)), ts1_vals, true, false)
    ts2 = TimeSeries(ts2_dates, ts2_vals, false, false)
    month2to3 = SpineInterface.parse_time_period("M2-3")
    month4to5 = SpineInterface.parse_time_period("M4-5")
    tp1 = Dict(month2to3 => 2.0, month4to5 => 3.0)
    tp2 = Dict(month2to3 => 8.0, month4to5 => -4.0)
    m_keys = [:one, :two]
    m1_vals = [ts1, ts2]
    m1 = Map(m_keys, m1_vals)
    m2_vals = [1, 2]
    m2 = Map(m_keys, m2_vals)
    # plus
    @test +ts1 == ts1
    @test ts1 + 4.2 == 4.2 + ts1 == TimeSeries(ts1.indexes, ts1.values .+ 4.2, false, false)
    @test ts1 + ts1 == ts1 * 2.0 == 2.0 * ts1
    @test ts1 + ts1_ignore_year == ts1_ignore_year + ts1 == TimeSeries(
        ts1.indexes, ts1.values .+ ts1_ignore_year.values, false, false
    )
    @test ts1_ignore_year + ts1_ignore_year == TimeSeries(
        ts1_ignore_year.indexes, ts1_ignore_year.values .+ ts1_ignore_year.values, true, false
    )
    @test ts1 + ts1_repeat == ts1_repeat + ts1 == TimeSeries(ts1.indexes, [2.0, 4.0, 5.0], false, false)
    @test ts1_repeat + ts1_repeat == TimeSeries(ts1_repeat.indexes, [2.0, 4.0, 2.0], false, true)
    @test ts1 + ts2 == ts2 + ts1 == TimeSeries([DateTime(1, i) for i in 2:4], [4.0, 5.0, 8.0], false, false)
    @test tp1 + 4.2 == 4.2 + tp1 == Dict(k => 4.2 + v for (k, v) in tp1)
    @test tp1 + tp1 == 2.0 * tp1 == tp1 * 2.0
    @test tp1 + tp2 == Dict(month2to3 => 2.0 + 8.0, month4to5 => 3.0 - 4.0)
    @test m1 + 1.0 == 1.0 + m1 == Map(m_keys, m1_vals .+ 1.0)
    @test m1 + ts1 == ts1 + m1 == Map(m_keys, [val + ts1 for val in m1_vals])
    @test m1 + tp1 == tp1 + m1 == Map(m_keys, [val + tp1 for val in m1_vals])
    @test m1 + m2 == m2 + m1 == Map(m_keys, [val1 + val2 for (val1, val2) in zip(m1.values, m2.values)])
    # minus
    @test ts1 + tp1 == tp1 + ts1 == TimeSeries(ts1_dates[2:end], [2.0 + 2.0, 4.0 + 3.0], false, false)
    @test -ts1 == TimeSeries(ts1.indexes, -ts1.values, false, false)
    @test ts1 - 4.2 == TimeSeries(ts1.indexes, ts1.values .- 4.2, false, false)
    @test 4.2 - ts1 == TimeSeries(ts1.indexes, 4.2 .- ts1.values, false, false)
    @test ts1 - ts1 == TimeSeries(ts1.indexes, ts1.values .- ts1.values, false, false)
    @test tp1 - 4.2 ==Dict(k => v - 4.2 for (k, v) in tp1)
    @test 4.2 - tp1 == Dict(k => 4.2 - v for (k, v) in tp1)
    @test ts1 - tp1 == TimeSeries(ts1_dates[2:end], [2.0 - 2.0, 4.0 - 3.0], false, false)
    @test tp1 - ts1 == TimeSeries(ts1_dates[2:end], [2.0 - 2.0, 3.0 - 4.0], false, false)
    @test tp1 - tp2 == Dict(month2to3 => 2.0 - 8.0, month4to5 => 3.0 + 4.0)
    @test m1 - 1.0 == Map(m_keys, m1_vals .- 1.0)
    @test 1.0 - m1 == Map(m_keys, 1.0 .- m1_vals)
    @test m1 - ts1 == Map(m_keys, [val - ts1 for val in m1_vals])
    @test ts1 - m1 == Map(m_keys, [ts1 - val for val in m1_vals])
    @test m1 - tp1 == Map(m_keys, [val - tp1 for val in m1_vals])
    @test tp1 - m1 == Map(m_keys, [tp1 - val for val in m1_vals])
    @test m1 - m2 == Map(m_keys, [val1 - val2 for (val1, val2) in zip(m1.values, m2.values)])
    @test m2 - m1 == Map(m_keys, [val2 - val1 for (val2, val1) in zip(m2.values, m1.values)])
    # times
    @test ts1 * 2.0 == 2.0 * ts1 == TimeSeries(ts1.indexes, 2.0 * ts1.values, false, false)
    @test tp1 * 2.0 == 2.0 * tp1 == Dict(month2to3 => 4.0, month4to5 => 6.0)
    @test ts1 * ts1 == ts1 ^ 2.0
    @test ts1 * tp1 == tp1 * ts1 == TimeSeries(ts1_dates[2:end], [2.0 * 2.0, 3.0 * 4.0], false, false)
    @test tp1 * tp2 == tp2 * tp1 == Dict(month2to3 => 2.0 * 8.0, month4to5 => 3.0 * -4.0)
    @test m1 * 2.0 == 2.0 * m1 == Map(m_keys, m1_vals .* 2.0)
    @test m1 * ts1 == ts1 * m1 == Map(m_keys, [val * ts1 for val in m1_vals])
    @test m1 * tp1 == tp1 * m1 == Map(m_keys, [val * tp1 for val in m1_vals])
    @test m1 * m2 == m2 * m1 == Map(m_keys, [val1 * val2 for (val1, val2) in zip(m1.values, m2.values)])
    # divided by
    @test ts1 / 2.0 == TimeSeries(ts1.indexes, ts1.values ./ 2.0, false, false)
    @test 2.0 / ts1 == TimeSeries(ts1.indexes, 2.0 ./ ts1.values, false, false)
    @test tp1 / 2.0 == Dict(k => v / 2.0 for (k, v) in tp1)
    @test 2.0 / tp1 == Dict(k => 2.0 / v for (k, v) in tp1)
    @test ts1 / ts1 == TimeSeries(ts1.indexes, ts1.values ./ ts1.values, false, false)
    @test ts1 / tp1 == TimeSeries(ts1.indexes[2:end], [2.0 / 2.0, 4.0 / 3.0], false, false)
    @test tp1 / ts1 == TimeSeries(ts1.indexes[2:end], [2.0 / 2.0, 3.0 / 4.0], false, false)
    @test tp1 / tp1 == Dict(k => 1.0 for (k, v) in tp1)
    @test m1 / 2.0 == Map(m_keys, m1_vals ./ 2.0)
    @test 2.0 / m1 == Map(m_keys, 2.0 ./ m1_vals)
    @test m1 / ts1 == Map(m_keys, [val / ts1 for val in m1_vals])
    @test ts1 / m1 == Map(m_keys, [ts1 / val for val in m1_vals])
    @test m1 / tp1 == Map(m_keys, [val / tp1 for val in m1_vals])
    @test tp1 / m1 == Map(m_keys, [tp1 / val for val in m1_vals])
    @test m1 / m2 == Map(m_keys, [val1 / val2 for (val1, val2) in zip(m1.values, m2.values)])
    @test m2 / m1 == Map(m_keys, [val2 / val1 for (val2, val1) in zip(m2.values, m1.values)])
    # to the power of
    @test ts1 ^ 2.0 == TimeSeries(ts1.indexes, ts1.values .^ 2.0, false, false)
    @test tp1 ^ 2.0 == Dict(k => v ^ 2.0 for (k, v) in tp1)
    @test 2.0 ^ ts1 == TimeSeries(ts1.indexes, 2.0 .^ ts1.values, false, false)
    @test 2.0 ^ tp1 == Dict(k => 2.0 ^ v for (k, v) in tp1)
    @test ts1 ^ ts2 == TimeSeries([DateTime(1, i) for i in 1:4], [1.0, 4.0, 8.0, 256.0], false, false)
    @test ts1 ^ tp1 == TimeSeries(ts1.indexes, [1.0, 4.0, 64.0], false, false)
    @test tp1 ^ ts1 == TimeSeries(ts1.indexes[2:end], [4.0, 81.0], false, false)
    @test tp1 ^ tp2 == Dict(month2to3 => 2.0 ^ 8.0, month4to5 => 3.0 ^ -4.0)
    @test m1 ^ 2.0 == Map(m_keys, m1_vals .^ 2.0)
    @test 2.0 ^ m1 == Map(m_keys, 2.0 .^ m1_vals)
    @test m1 ^ ts1 == Map(m_keys, [val ^ ts1 for val in m1_vals])
    @test ts1 ^ m1 == Map(m_keys, [ts1 ^ val for val in m1_vals])
    @test m1 ^ tp1 == Map(m_keys, [val ^ tp1 for val in m1_vals])
    @test tp1 ^ m1 == Map(m_keys, [tp1 ^ val for val in m1_vals])
    @test m1 ^ m2 == Map(m_keys, [val1 ^ val2 for (val1, val2) in zip(m1.values, m2.values)])
    @test m2 ^ m1 == Map(m_keys, [val2 ^ val1 for (val2, val1) in zip(m2.values, m1.values)])
    # Test timedata_operation for single-argument functions
    @test timedata_operation(float, 0) == float(0)
    @test timedata_operation(float, ts1) == TimeSeries(ts1.indexes, float.(ts1.values), ts1.ignore_year, ts1.repeat)
    @test timedata_operation(float, tp1) == Dict(month2to3 => 2.0, month4to5 => 3.0)
    @test timedata_operation(float, m1) == Map(m_keys, [timedata_operation(float, val) for val in m1_vals])
    @test timedata_operation(float, m2) == Map(m_keys, float.(m2_vals))
    m = Map(collect(1:4), collect(5:8))
    # values
    @test values(ts1) == ts1_vals
    @test sort(collect(values(tp1))) == [2, 3]
    @test values(m) == collect(5:8)
    @test values(parameter_value(ts1)) == values(ts1)
    @test values(parameter_value(m)) == parameter_value.(values(m))
    # keys
    @test keys(ts1) == ts1_dates
    @test keys(m) == collect(1:4)
    @test keys(parameter_value(ts1)) == keys(ts1)
    @test keys(parameter_value(m)) == keys(m)
    # push
    ts = TimeSeries(ts1_dates, ts1_vals, false, false)
    @test push!(ts, DateTime(9) => 40) == TimeSeries([ts1_dates; DateTime(9)], [ts1_vals; 40], false, false)
    ts = TimeSeries(ts1_dates, ts1_vals, false, false)
    @test push!(ts, DateTime(1) => 40) == TimeSeries(ts1_dates, [40; ts1_vals[2:end]], false, false)
    # setindex
    ts = TimeSeries(ts1_dates, ts1_vals, false, false)
    @test (ts[DateTime(9)] = 5) == 5
    @test ts == TimeSeries([ts1_dates; DateTime(9)], [ts1_vals; 5], false, false)
    # get
    m = Map(collect(1:4), collect(5:8))
    ts = TimeSeries(ts1_dates, ts1_vals, false, false)
    @test get(m, 1, nothing) == 5
    @test get(m, 7, nothing) === nothing
    @test get(ts, DateTime(1, 4), nothing) == 4
    @test get(ts, DateTime(8, 4), nothing) === nothing
    # iterate
    @test iterate(ts1) == (ts1_dates[1] => ts1_vals[1], 2)
    @test iterate(ts1, 2) == (ts1_dates[2] => ts1_vals[2], 3)
    @test isnothing(iterate(ts1, 4))
    @test iterate(m) == (1 => 5, 2)
    @test iterate(m, 3) == (3 => 7, 4)
    @test isnothing(iterate(m, 5))
    # AbstractParameterValue consistency
    @test parameter_value(ts1)() == ts1
    @test parameter_value(ts1)(asd = :asd) == ts1
    @test parameter_value(tp1)() == tp1
    @test parameter_value(tp1)(asd = :asd) == tp1
    @test parameter_value(m1)() == m1
    @test parameter_value(m1)(asd = :asd) == m1
    # isempty
    @test !isempty(ts1)
    @test !isempty(m)
    @test isempty(TimeSeries([],[], false, false))
    @test isempty(Map([],[]))
end
@testset "TimePattern-TimePattern arithmetic" begin
    month1to3or7to12 = SpineInterface.parse_time_period("M1-3,M7-12")
    month4to6 = SpineInterface.parse_time_period("M4-6")
    weekday1to5 = SpineInterface.parse_time_period("WD1-5")
    weekday6to7 = SpineInterface.parse_time_period("WD6-7")
    weekday3to6 = SpineInterface.parse_time_period("WD3-6")
    tp1 = Dict(month1to3or7to12 => 1, month4to6 => 2)
    tp2 = Dict(weekday1to5 => 1, weekday6to7 => 2)
    tp3 = Dict(weekday3to6 => 10)
    observed = tp1 + tp2
    expected = Dict(
        SpineInterface.parse_time_period("WD1-5;M1-3") => 2,
        SpineInterface.parse_time_period("WD1-5;M4-6") => 3,
        SpineInterface.parse_time_period("WD1-5;M7-12") => 2,
        SpineInterface.parse_time_period("WD6-7;M1-3") => 3,
        SpineInterface.parse_time_period("WD6-7;M4-6") => 4,
        SpineInterface.parse_time_period("WD6-7;M7-12") => 3,
    )
    @test observed == expected
    observed = tp2 - tp3
    expected = Dict(SpineInterface.parse_time_period("WD3-5") => -9, SpineInterface.parse_time_period("WD6-6") => -8)
    @test observed == expected
end
