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
    @test intersect(anything, 1) === 1
    @test intersect(anything, :Spine) === :Spine
    @test intersect([1, 2, 3], anything) == [1, 2, 3]
    @test "Spine" in anything
    @test [4, 5, 6] in anything
    Spine = Object(:Spine)
    Julia = Object(:Julia)
    @test [x for x in Spine] == [Spine]
    @test Julia < Spine
    t1 = TimeSlice(DateTime(0), DateTime(1))
    t2 = TimeSlice(DateTime(1), DateTime(2))
    @test [x for x in t1] == [t1]
    @test t1 < t2
    p5 = parameter_value(5)
    p7 = parameter_value(7)
    @test [x for x in p5] == [p5]
    @test p5 < p7
    d = Dict(anything => nothing)
    @test d[anything] === nothing
    @test string(anything) === "anything"
    @test string(t1) === "0000-01-01T00:00 ~> 0001-01-01T00:00"
    @test string(p5) === "5"
    duck = ObjectClass(:duck, [])
    studio_duck = RelationshipClass(:studio_duck, [:studio, :duck], [])
    @test string(duck) === "duck"
    @test string(studio_duck) === "studio_duck"
    id_call = Call(13)
    op_call = Call(+, (2, 3))
    uses_pants = Parameter(:uses_pants)
    param_call = Call(uses_pants, (duck=:Daffy,))
    @test string(id_call) === "13"
    @test string(op_call) === "2 + 3"
    @test string(param_call) === "uses_pants(duck=Daffy)"
    pc = SpineInterface.PeriodCollection("Y1-5;M1-4,M6-9")
    @test string(pc) === "year from 1 to 5, and month from 1 to 4, or 6 to 9"




end
