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
    @test intersect(anything, 1) === 1
    @test intersect(anything, :Spine) === :Spine
    @test intersect([1, 2, 3], anything) == [1, 2, 3]
    # in, iterate, length, isless
    @test "Spine" in anything
    @test [4, 5, 6] in anything
    Spine = Object(:Spine, 1)
    Julia = Object(:Julia, 2)
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
    # hash?
    d = Dict(anything => nothing)
    @test d[anything] === nothing
    # show
    @test string(anything) === "anything"
    @test string(t1) === "0000-01-01T00:00 ~> 0001-01-01T00:00"
    @test string(p5) === "5"
    duck = ObjectClass(:duck, [])
    studio_duck = RelationshipClass(:studio_duck, [:studio, :duck], [])
    @test string(duck) === "duck"
    @test string(studio_duck) === "studio_duck"
    id_call = Call(13)
    op_call = Call(+, (2, 3))
    apero_time = parameter_value("apero_time")
    param_val_call = Call(apero_time, (scenario=:covid,))
    @test string(id_call) === "13"
    @test string(op_call) === "2 + 3"
    @test string(param_val_call) === "apero_time(scenario=covid)"
    pc = SpineInterface.PeriodCollection("Y1-5;M1-4,M6-9")
    @test string(pc) === "year from 1 to 5, and month from 1 to 4, or 6 to 9"
    # convert
    call = convert(Call, 9)
    @test call isa Call
    @test realize(call) === 9
    # copy
    val = parameter_value(nothing)
    val_copy = copy(val)
    @test val_copy isa SpineInterface.NothingParameterValue
    @test val_copy() === nothing
    val = parameter_value(10)
    val_copy = copy(val)
    @test val_copy isa SpineInterface.ScalarParameterValue
    @test val_copy() === 10
    val = parameter_value(SpineInterface.Array_([4, 5, 6]))
    val_copy = copy(val)
    @test val_copy isa SpineInterface.ArrayParameterValue
    @test val_copy(i=1) === 4
    @test val_copy(i=2) === 5
    @test val_copy(i=3) === 6
    val = parameter_value(Dict(pc => 14))
    val_copy = copy(val)
    @test val_copy isa SpineInterface.TimePatternParameterValue
    @test convert(Int64, val_copy(t=TimeSlice(DateTime(1), DateTime(4)))) === 14
    ts = TimeSeries([DateTime(4), DateTime(5)], [100, 8], false, false)
    val = parameter_value(ts)
    val_copy = copy(val)
    @test val_copy isa SpineInterface.StandardTimeSeriesParameterValue
    @test convert(Int64, val_copy(t=TimeSlice(DateTime(4), DateTime(5)))) === 100
    ts = TimeSeries([DateTime(4), DateTime(5)], [100, 8], false, true)
    val = parameter_value(ts)
    val_copy = copy(val)
    @test val_copy isa SpineInterface.RepeatingTimeSeriesParameterValue
    @test val_copy(t=TimeSlice(DateTime(6), DateTime(7))) === div(100 + 8, 2)
    call_copy = copy(id_call)
    @test call_copy isa SpineInterface.IdentityCall
    @test string(call_copy) === "13"
    call_copy = copy(op_call)
    @test call_copy isa SpineInterface.OperatorCall
    @test string(call_copy) === "2 + 3"
    call_copy = copy(param_val_call)
    @test call_copy isa SpineInterface.ParameterValueCall
    @test string(call_copy) === "apero_time(scenario=covid)"
    # Call zero
    zero_call = zero(call)
    @test zero_call isa Call
    @test iszero(zero_call)
    @test iszero(realize(zero_call))
    @test zero_call === zero(Call)
    # Call one
    one_call = one(call)
    @test one_call isa Call
    @test isone(one_call)
    @test isone(realize(one_call))
    @test one_call === one(Call)
    # Call plus
    call = +one_call
    @test op_call isa Call
    @test convert(Int, realize(call)) === 1
    op_call = zero_call + one_call
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 1
    op_call = zero_call + 1
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 1
    op_call = 0 + one_call
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 1
    # Call minus
    call = -one_call
    @test op_call isa Call
    @test convert(Int, realize(call)) === -1
    op_call = zero_call - one_call
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === -1
    op_call = 0 - one_call
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === -1
    op_call = zero_call - 1
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === -1
    # Call times
    op_call = zero_call * one_call
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    op_call = 0 * one_call
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    op_call = zero_call * 1
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    # Call div
    op_call = zero_call / one_call
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    op_call = 0 / one_call
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    op_call = zero_call / 1
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    # Call min
    op_call = min(zero_call, one_call)
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    op_call = min(0, one_call)
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    op_call = min(zero_call, 1)
    @test op_call isa SpineInterface.OperatorCall
    @test convert(Int, realize(op_call)) === 0
    # Call abs
    abs_call = abs(Call(-5))
    @test abs_call isa Call
    @test realize(abs_call) === 5
end
