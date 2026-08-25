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
            data = Dict([
                "entity_classes" => class_data,
                "parameter_definitions" => definition_data,
                "entities" => entity_data,
                "parameter_values" => value_data,
            ])
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

function _test_data_to_import()
    @testset "data_to_import" begin
        @testset "0D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            data = data_to_import(graph)
            @test data == Dict([:entity_classes => [[:Object]]])
        end
        @testset "2D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_relationship_class!(graph, :A__B, :A, :B)
            data = data_to_import(graph)
            @test length(data) == 1
            classes = data[:entity_classes]
            @test length(classes) == 3
            @test sort(classes[1:2]) == sort([[:A], [:B]])
            @test classes[3] == [:A__B, [:A, :B]]
        end
        @testset "superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_superclass!(graph, :super, :A, :B)
            data = data_to_import(graph)
            @test length(data) == 2
            classes = data[:entity_classes]
            @test length(classes) == 3
            @test sort(classes[1:2]) == sort([[:A], [:B]])
            @test classes[3] == [:super]
            superclasses = data[:superclasses]
            @test sort(superclasses) == sort([[:super, :A], [:super, :B]])
        end
        @testset "parameter definitions" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_parameter_definition!(graph, :Object, :X)
            add_parameter_definition!(graph, :Object, :Y, parameter_value(2.3))
            data = data_to_import(graph)
            @test length(data) == 2
            @test data[:entity_classes] == [[:Object]]
            @test sort(data[:parameter_definitions]) == sort([
                [:Object, :X, unparse_db_value(parameter_value(nothing))],
                [:Object, :Y, unparse_db_value(parameter_value(2.3))],
            ])
        end
        @testset "0D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_entity!(graph, :Object, :thing)
            data = data_to_import(graph)
            @test data == Dict([:entity_classes => [[:Object]], :entities => [[:Object, :thing]]])
        end
        @testset "2D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_relationship_class!(graph, :A__B, :A, :B)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :B, :b)
            add_entity!(graph, :A__B, :A => :a, :B => :b)
            data = data_to_import(graph)
            @test length(data) == 2
            classes = data[:entity_classes]
            @test length(classes) == 3
            @test sort(data[:entity_classes][1:2]) == sort([[:A], [:B]])
            @test data[:entity_classes][3] == [:A__B, [:A, :B]]
            entities = data[:entities]
            @test length(entities) == 3
            @test sort(entities[1:2]) == sort([[:A, :a], [:B, :b]])
            @test entities[3] == [:A__B, [:a, :b]]
        end
        @testset "0D parameter value" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_parameter_definition!(graph, :Object, :X)
            add_entity!(graph, :Object, :thing)
            set_parameter_value!(graph, :Object, :X, parameter_value(2.3), :thing)
            data = data_to_import(graph)
            @test data == Dict([
                :entity_classes => [[:Object]],
                :entities => [[:Object, :thing]],
                :parameter_definitions => [[:Object, :X, unparse_db_value(parameter_value(nothing))]],
                :parameter_values => [[:Object, :thing, :X, unparse_db_value(parameter_value(2.3))]],
            ])
        end
        @testset "2D parameter value" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_relationship_class!(graph, :A__B, :A, :B)
            add_parameter_definition!(graph, :A__B, :X)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :B, :b)
            add_entity!(graph, :A__B, :A => :a, :B => :b)
            set_parameter_value!(graph, :A__B, :X, parameter_value(2.3), :A => :a, :B => :b)
            data = data_to_import(graph)
            @test length(data) == 4
            classes = data[:entity_classes]
            @test length(classes) == 3
            @test sort(data[:entity_classes][1:2]) == sort([[:A], [:B]])
            @test data[:entity_classes][3] == [:A__B, [:A, :B]]
            @test data[:parameter_definitions] == [[:A__B, :X, unparse_db_value(parameter_value(nothing))]]
            entities = data[:entities]
            @test length(entities) == 3
            @test sort(entities[1:2]) == sort([[:A, :a], [:B, :b]])
            @test entities[3] == [:A__B, [:a, :b]]
            @test data[:parameter_values] == [[:A__B, [:a, :b], :X, unparse_db_value(parameter_value(2.3))]]
        end
    end
end

@testset "db" begin
    _test_build_entity_class_graph()
    _test_data_to_import()
end
