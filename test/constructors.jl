#############################################################################
# Copyright (C) 2017 - 2021 Spine project consortium
# Copyright SpineInterface contributors
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
    graph = empty_entity_class_graph()
    add_object_class!(graph, :duck)
    ducks = [Object(:Daffy), Object(:Donald)]
    for d in ducks
        add_entity!(graph, :duck, d.name)
    end
    duck = ObjectClass(:duck, graph)
    @test duck isa ObjectClass
    @test sort([o.name for o in duck()]) == sort([o.name for o in ducks])
    add_object_class!(graph, :studio)
    studios = [Object(:WB), Object(:Disney)]
    for s in studios
        add_entity!(graph, :studio, s.name)
    end
    studio = ObjectClass(:studio, graph)
    studio_duck_rels = [(studio=s, duck=d) for (s, d) in zip(studios, ducks)]
    add_relationship_class!(graph, :studio__duck, :studio, :duck)
    for (s, d) in studio_duck_rels
        add_entity!(graph, :studio__duck, studio.name => s.name, duck.name => d.name)
    end
    object_classes = Dict(c.name => c for c in (duck, studio))
    studio__duck = RelationshipClass(:studio__duck, graph, object_classes)
    @test studio__duck isa RelationshipClass
    @test sort(studio__duck()) == sort([(studio=studio(:WB), duck=duck(:Daffy)), (studio=studio(:Disney), duck=duck(:Donald))])
    color_vals = ("black", "white")
    uses_pants_vals = (false, TimeSeries([DateTime(0)], [1.0], false, false))
    studio_duck_param_vals = Dict(
        (s, d) => Dict(:color => parameter_value(c), :uses_pants => parameter_value(up))
        for (s, d, c, up) in zip(studios, ducks, color_vals, uses_pants_vals)
    )
    add_parameter_definition!(graph, :studio__duck, :color, parameter_value(nothing))
    add_parameter_definition!(graph, :studio__duck, :uses_pants, parameter_value(nothing))
    for (s, d, c, up) in zip(studios, ducks, color_vals, uses_pants_vals)
        set_parameter_value!(graph, :studio__duck, :color, :studio => s.name, :duck => d.name, parameter_value(c))
        set_parameter_value!(graph, :studio__duck, :uses_pants, :studio =>s.name, :duck => d.name, parameter_value(up))
    end
    color = Parameter(:color, graph, [studio__duck])
    uses_pants = Parameter(:uses_pants, graph, [studio__duck])
    t = TimeSlice(DateTime(0), DateTime(1))
    @test !uses_pants(studio=studio(:WB), duck=duck(:Daffy), t=t)
    @test uses_pants(studio=studio(:Disney), duck=duck(:Donald), t=t) == 1.0
    @test uses_pants(studio=studio(:WB), duck=duck(:Donald), t=t, _strict=false) === nothing
    @test uses_pants(studio=studio(:Disney), duck=duck(:Daffy)) === nothing
    @test color(studio=studio(:WB), duck=duck(:Daffy)) === :black
    @test color(studio=studio(:Disney), duck=duck(:Donald)) === :white
    dummy = Parameter(:dummy, graph)
    @test dummy isa Parameter
    call = uses_pants[(studio=studio(:Disney), duck=duck(:Donald), t=t)]
    @test call isa Call
    same_call = Call(call)
    @test same_call isa Call
    @test realize(same_call) == 1.0
    @test_throws ErrorException("invalid lower bound x.") SpineInterface.parse_time_period("Mx-4")
    @test_throws ErrorException("invalid upper bound x.") SpineInterface.parse_time_period("M5-x")
end
