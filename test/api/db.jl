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

function _test_build_entity_class_graph()
    @testset "build_entity_class_graph" begin
        @testset "empty input data -> empty graph" begin
            graph = build_entity_class_graph(Dict())
            @test isempty(collect(class_labels(graph)))
        end
        @testset "0D entity class" begin
            class_data = [["Object"]]
            data = Dict(["entity_classes" => class_data])
            graph = build_entity_class_graph(data)
            @test collect(class_labels(graph)) == [:Object]
        end
        @testset "0D entity class by name only" begin
            class_data = ["Object"]
            data = Dict(["entity_classes" => class_data])
            graph = build_entity_class_graph(data)
            @test collect(class_labels(graph)) == [:Object]
        end
        @testset "2D relationship class" begin
            class_data = [["A__B", ["A", "B"]], ["A"], ["B"]]
            data = Dict(["entity_classes" => class_data])
            graph = build_entity_class_graph(data)
            @test sort(collect(class_labels(graph))) == sort([:A, :B, :A__B])
        end
        @testset "superclass" begin
            class_data = ["sub1", "sub2", "super"]
            superclass_data = [["super", "sub1"], ["super", "sub2"]]
            data = Dict(["entity_classes" => class_data, "superclass_subclasses" => superclass_data])
            graph = build_entity_class_graph(data)
            @test sort(collect(class_labels(graph))) == sort([:super, :sub1, :sub2])
            @test is_superclass(graph, :super)
            @test is_subclass_of(graph, :sub1, :super)
            @test is_subclass_of(graph, :sub2, :super)
        end
        @testset "parameter definition" begin
            class_data = ["Object"]
            definition_data = [["Object", "no_default", nothing], ["Object", "with_default", 2.3]]
            data = Dict(["entity_classes" => class_data, "parameter_definitions" => definition_data])
            graph = build_entity_class_graph(data)
            @test default_value(graph, :Object, :no_default) == parameter_value(nothing)
        end
        @testset "0D entity" begin
            class_data = ["Object"]
            entity_data = [["Object", "a"]]
            data = Dict(["entity_classes" => class_data, "entities" => entity_data])
            graph = build_entity_class_graph(data)
            @test collect(entities(graph, :Object)) == [:a]
        end
        @testset "2D entity" begin
            class_data = [["A__B", ["A", "B"]], ["A"], ["B"]]
            entity_data = [["A", "a"], ["B", "b"], ["A__B", ["a", "b"]]]
            data = Dict(["entity_classes" => class_data, "entities" => entity_data])
            graph = build_entity_class_graph(data)
            @test collect(entities(graph, :A__B)) == [(:A => :a, :B => :b)]
        end
        @testset "parameter value" begin
            class_data = ["Object"]
            definition_data = [["Object", "attribute", nothing]]
            entity_data = [["Object", "a"]]
            value_data = [["Object", "a", "attribute", 2.3]]
            data = Dict(["entity_classes" => class_data, "parameter_definitions" => definition_data, "entities" => entity_data, "parameter_values" => value_data])
            graph = build_entity_class_graph(data)
            @test find_value(graph, :Object, :attribute, :a) == parameter_value(2.3)
        end
        @testset "entity group" begin
            class_data = ["Object"]
            entity_data = [["Object", "boss"], ["Object", "henchman1"], ["Object", "henchman2"]]
            group_data = [["Object", "boss", "henchman1"], ["Object", "boss", "henchman2"]]
            data = Dict(["entity_classes" => class_data, "entities" => entity_data, "entity_groups" => group_data])
            graph = build_entity_class_graph(data)
            @test sort(collect(entity_group_members(graph, :Object, :boss))) == sort([:henchman1, :henchman2])
        end
    end
end

@testset "db" begin
    _test_build_entity_class_graph()
end
