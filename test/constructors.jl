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

@testset "constructors" begin
    ducks = [Object(:Daffy), Object(:Donald)]
    duck = ObjectClass(:duck, ducks)
    @test duck isa ObjectClass
    @test duck() == ducks
    studios = [Object(:WB), Object(:Disney)]
    studio = ObjectClass(:studio, studios)
    studio_duck_rels = [(studio=s, duck=d) for (s, d) in zip(studios, ducks)]
    studio__duck = RelationshipClass(:studio__duck, [:studio, :duck], studio_duck_rels)
    @test studio__duck isa RelationshipClass
    @test studio__duck() == studio_duck_rels
    color_vals = ("black", "white")
    uses_pants_vals = (false, false)
    studio_duck_param_vals = Dict(
        (s, d) => Dict(:color => parameter_value(c), :uses_pants => parameter_value(up))
        for (s, d, c, up) in zip(studios, ducks, color_vals, uses_pants_vals)
    )
    studio__duck = RelationshipClass(:studio__duck, [:studio, :duck], studio_duck_rels, studio_duck_param_vals)
    color = Parameter(:color, [studio__duck])
    uses_pants = Parameter(:uses_pants, [studio__duck])
    @test !uses_pants(studio=studio(:WB), duck=duck(:Daffy)) 
    @test !uses_pants(studio=studio(:Disney), duck=duck(:Donald)) 
    @test uses_pants(studio=studio(:WB), duck=duck(:Donald), _strict=false) === nothing
    @test_throws ErrorException uses_pants(studio=studio(:Disney), duck=duck(:Daffy))
    @test color(studio=studio(:WB), duck=duck(:Daffy)) === :black
    @test color(studio=studio(:Disney), duck=duck(:Donald)) === :white
    dummy = Parameter(:dummy)
    @test dummy isa Parameter
    call = uses_pants[(studio=studio(:WB), duck=duck(:Daffy))]
    @test call isa Call
    same_call = Call(call)
    @test same_call isa Call
    @test !realize(same_call)
    @test_throws ErrorException("invalid lower bound x.") SpineInterface.PeriodCollection("Mx-4")
    @test_throws ErrorException("invalid upper bound x.") SpineInterface.PeriodCollection("M5-x")
end
