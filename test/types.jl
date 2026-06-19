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

function _test_object_class()
    @testset "ObjectClass" begin
        @testset "construction with objects" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :unit)
            add_entity!(graph, :unit, :flower_plant)
            add_entity!(graph, :unit, :lava_plant)
            objects = Dict([
                :flower_plant => Object(:flower_plant, :unit),
                :lava_plant => Object(:lava_plant, :unit)
            ])
            unit = ObjectClass(:unit, graph, objects)
            @test unit.name == :unit
            env_dict = unit.env_dict[SpineInterface._active_env()]
            @test env_dict.entity_class_graph === graph
            @test env_dict.vertex === graph[:unit]
            @test env_dict.objects == Dict(
                [
                    :flower_plant => Object(:flower_plant, :unit),
                    :lava_plant => Object(:lava_plant, :unit)
                ]
            )
        end
    end
end

function _test_relationship_class()
    @testset "RelationshipClass" begin
        @testset "normal construction" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :bondable)
            add_relationship_class!(graph, :bond, :bondable)
            bondable = ObjectClass(:bondable, graph)
            object_classes = Dict([:bondable => bondable])
            relationship_class = SpineInterface.RelationshipClass(:bond, graph, object_classes)
            @test relationship_class.name == :bond
            env_dict = relationship_class.env_dict[SpineInterface._active_env()]
            @test env_dict.entity_class_graph === graph
            @test env_dict.vertex === graph[:bond]
            @test env_dict.object_classes === object_classes
            @test env_dict.legacy_dimension_map == Dict([:bondable => [1]])
        end
        @testset "degenerate dimensions" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :bondable)
            add_relationship_class!(graph, :bond, :bondable, :bondable)
            bondable = ObjectClass(:bondable, graph)
            object_classes = Dict([:bondable => bondable])
            relationship_class = SpineInterface.RelationshipClass(:bond, graph, object_classes)
            @test relationship_class.name == :bond
            env_dict = relationship_class.env_dict[SpineInterface._active_env()]
            @test env_dict.entity_class_graph === graph
            @test env_dict.vertex === graph[:bond]
            @test env_dict.object_classes === object_classes
            @test env_dict.legacy_dimension_map == Dict([:bondable => [1, 2]])
        end
    end
end

@testset "type" begin
    _test_object_class()
    _test_relationship_class()
end
