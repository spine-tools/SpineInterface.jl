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

function _test_empty_entity_class_graph()
    @testset "empty_entity_class_graph" begin
        graph = empty_entity_class_graph()
        @test Graphs.nv(graph) == 0
    end
end

function _test_add_object_class()
    @testset "add_object_class!" begin
        @testset "normal use case" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectClass)
            @test Graphs.nv(graph) == 1
            class_vertex = graph[:ObjectClass]
            @test isempty(class_vertex.entities)
            @test Graphs.nv(class_vertex.entity_group_graph) == 0
            @test isempty(class_vertex.parameter_values)
            @test isempty(class_vertex.parameter_defaults)
        end
    end
end

function _test_add_relationship_class()
    @testset "add_relationship_class!" begin
        @testset "normal use case" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_relationship_class!(graph, :ObjectA__ObjectB, :ObjectA, :ObjectB)
            @test Graphs.nv(graph) == 3
            @test Graphs.ne(graph) == 2
            @test graph[:ObjectA, :ObjectA__ObjectB] == [1]
            @test graph[:ObjectB, :ObjectA__ObjectB] == [2]
            class_vertex = graph[:ObjectA__ObjectB]
            @test isempty(class_vertex.entities)
            @test class_vertex.relationship_graph[].atomic_dimensionality == 2
            @test Graphs.nv(class_vertex.relationship_graph) == 0
            @test class_vertex.atomic_dimension_choices == [[:ObjectA], [:ObjectB]]
            @test isempty(class_vertex.parameter_values)
            @test isempty(class_vertex.parameter_defaults)
        end
        @testset "same object class in both dimensions" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_relationship_class!(graph, :Object__Object, :Object, :Object)
            @test Graphs.nv(graph) == 2
            @test Graphs.ne(graph) == 1
            @test graph[:Object, :Object__Object] == [1, 2]
            class_vertex = graph[:Object__Object]
            @test isempty(class_vertex.entities)
            @test class_vertex.relationship_graph[].atomic_dimensionality == 2
            @test Graphs.nv(class_vertex.relationship_graph) == 0
            @test class_vertex.atomic_dimension_choices == [[:Object], [:Object]]
            @test isempty(class_vertex.parameter_values)
            @test isempty(class_vertex.parameter_defaults)
        end
    end
end

function _test_add_superclass()
    @testset "add_superclass!" begin
        @testset "two object classes as subclasses" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_superclass!(graph, :Super, :ObjectA, :ObjectB)
            @test Graphs.nv(graph) == 3
            @test Graphs.ne(graph) == 2
            @test isempty(graph[:ObjectA, :Super])
            @test isempty(graph[:ObjectB, :Super])
            class_vertex = graph[:Super]
            @test isempty(class_vertex.parameter_defaults)
        end
    end
end

function _test_dimensionality()
    @testset "dimensionality" begin
        @testset "object class dimensions" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            @test SpineInterface.dimensionality(graph, :Object) == 0
        end
        @testset "simple relationship class dimensions" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_relationship_class!(graph, :ObjectA__ObjectB, :ObjectA, :ObjectB)
            @test SpineInterface.dimensionality(graph, :ObjectA__ObjectB) == 2
        end
        @testset "relationship class with repeated dimensions" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_relationship_class!(graph, :Object__Object, :Object, :Object)
            @test SpineInterface.dimensionality(graph, :Object__Object) == 2
        end
        @testset "relationship class of two superclasses" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_object_class!(graph, :ObjectC)
            add_object_class!(graph, :ObjectD)
            add_superclass!(graph, :AB, :ObjectA, :ObjectB)
            add_superclass!(graph, :CD, :ObjectC, :ObjectD)
            add_relationship_class!(graph, :AB__CD, :AB, :CD)
            @test SpineInterface.dimensionality(graph, :AB__CD) == 2
        end
        @testset "superclass of two relationship classes" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_object_class!(graph, :ObjectC)
            add_object_class!(graph, :ObjectD)
            add_relationship_class!(graph, :ObjectA__ObjectB, :ObjectA, :ObjectB)
            add_relationship_class!(graph, :ObjectC__ObjectD, :ObjectC, :ObjectD)
            add_superclass!(graph, :Object__Object, :ObjectA__ObjectB, :ObjectC__ObjectD)
            @test SpineInterface.dimensionality(graph, :Object__Object) == 2
        end
    end
end

function _test_dimensions_iterator()
    @testset "Dimensions" begin
        @testset "object class case" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            @test isempty([dim for dim in SpineInterface.Dimensions(graph, :Object)])
        end
        @testset "simple relationship class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_relationship_class!(graph, :ObjectA__ObjectB, :ObjectA, :ObjectB)
            @test Tuple(SpineInterface.Dimensions(graph, :ObjectA__ObjectB)) == (:ObjectA, :ObjectB)
        end
        @testset "relationship class with repeated dimensions" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_relationship_class!(graph, :Object__Object, :Object, :Object)
            @test Tuple(SpineInterface.Dimensions(graph, :Object__Object)) == (:Object, :Object)
        end
        @testset "superclass has no dimensions" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_superclass!(graph, :Super, :ObjectA, :ObjectB)
            @test isempty(Tuple(SpineInterface.Dimensions(graph, :Super)))
        end
    end
end

function _test_resolve_atomic_dimension_choices()
    @testset "resolve_atomic_dimension_choices" begin
        @testset "simple relationship class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            choices = SpineInterface.resolve_atomic_dimension_choices(graph, :ObjectA, :ObjectB)
            @test choices == [[:ObjectA], [:ObjectB]]
        end
        @testset "relationship of relationship" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_relationship_class!(graph, :A__B, :ObjectA, :ObjectB)
            choices = SpineInterface.resolve_atomic_dimension_choices(graph, :A__B)
            @test choices == [[:ObjectA], [:ObjectB]]
        end
        @testset "simple superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_superclass!(graph, :A_or_B, :ObjectA, :ObjectB)
            choices = SpineInterface.resolve_atomic_dimension_choices(graph, :A_or_B)
            @test choices == [[:ObjectA, :ObjectB]]
        end
        @testset "superclass of relationship classes" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_relationship_class!(graph, :A__B, :ObjectA, :ObjectB)
            add_object_class!(graph, :ObjectC)
            add_object_class!(graph, :ObjectD)
            add_relationship_class!(graph, :C__D, :ObjectC, :ObjectD)
            add_superclass!(graph, :A__B_or_C__D, :A__B, :C__D)
            choices = SpineInterface.resolve_atomic_dimension_choices(graph, :A__B_or_C__D)
            @test choices == [[:ObjectA, :ObjectC], [:ObjectB, :ObjectD]]
        end
        @testset "relationship class with object class and superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_object_class!(graph, :ObjectC)
            add_superclass!(graph, :A_or_B, :ObjectA, :ObjectB)
            add_superclass!(graph, :B_or_C, :ObjectB, :ObjectC)
            add_relationship_class!(graph, :AB__C, :A_or_B, :ObjectC)
            add_relationship_class!(graph, :A__BC, :ObjectA, :B_or_C)
            choices = SpineInterface.resolve_atomic_dimension_choices(graph, :AB__C)
            @test choices == [[:ObjectA, :ObjectB], [:ObjectC]]
            choices = SpineInterface.resolve_atomic_dimension_choices(graph, :A__BC)
            @test choices == [[:ObjectA], [:ObjectB, :ObjectC]]
        end
    end
end

function _test_has_entity()
    @testset "has_entity" begin
        @testset "0D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_entity!(graph, :ObjectA, :A)
            @test SpineInterface.has_entity(graph[:ObjectA], :A)
            @test !SpineInterface.has_entity(graph[:ObjectA], :B)
        end
        @testset "2D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_entity!(graph, :ObjectA, :A)
            add_object_class!(graph, :ObjectB)
            add_entity!(graph, :ObjectB, :B)
            add_relationship_class!(graph, :A__B, :ObjectA, :ObjectB)
            add_entity!(graph, :A__B, :ObjectA => :A, :ObjectB => :B)
            @test SpineInterface.has_entity(graph[:A__B], :ObjectA => :A, :ObjectB => :B)
            @test !SpineInterface.has_entity(graph[:A__B], :ObjectA => :A, :ObjectB => :none)
        end
    end
end

function _test_add_entity()
    @testset "add_entity!" begin
        @testset "0D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            object_label = add_entity!(graph, :ObjectA, :A)
            @test object_label == :A
            @test graph[:ObjectA].entities == Set([:A])
        end
        @testset "2D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_entity!(graph, :ObjectA, :A)
            add_object_class!(graph, :ObjectB)
            add_entity!(graph, :ObjectB, :B)
            add_relationship_class!(graph, :A__B, :ObjectA, :ObjectB)
            relationship_label = add_entity!(graph, :A__B, :ObjectA => :A, :ObjectB => :B)
            @test graph[:A__B].entities == Set([relationship_label])
            relationship_graph = graph[:A__B].relationship_graph
            @test Graphs.nv(relationship_graph) == 3
            @test Graphs.ne(relationship_graph) == 2
            @test relationship_graph[:ObjectA => :A, relationship_label] == [1]
            @test relationship_graph[:ObjectB => :B, relationship_label] == [2]
        end
        @testset "reuse nodes" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_entity!(graph, :A, :a1)
            add_entity!(graph, :A, :a2)
            add_entity!(graph, :B, :b)
            add_relationship_class!(graph, :A__B, :A, :B)
            relationship_graph = graph[:A__B].relationship_graph
            relationship_label1 = add_entity!(graph, :A__B, :A => :a1, :B => :b)
            relationship_label2 = add_entity!(graph, :A__B, :A => :a2, :B => :b)
            @test graph[:A__B].entities == Set([relationship_label1, relationship_label2])
            @test Graphs.nv(relationship_graph) == 5
            @test Graphs.ne(relationship_graph) == 4
            @test relationship_graph[:A => :a1, relationship_label1] == [1]
            @test relationship_graph[:A => :a2, relationship_label2] == [1]
            @test relationship_graph[:B => :b, relationship_label1] == [2]
            @test relationship_graph[:B => :b, relationship_label2] == [2]
        end
    end
end

function _test_add_entity_group_member()
    @testset "add_entity_group_member!" begin
        @testset "higher level interface" begin
            entity_class_graph = empty_entity_class_graph()
            add_object_class!(entity_class_graph, :Class)
            add_entity!(entity_class_graph, :Class, :group_object)
            add_entity!(entity_class_graph, :Class, :member_object)
            add_entity_group_member!(entity_class_graph, :Class, :group_object, :member_object)
            @test collect(SpineInterface.entity_group_members(entity_class_graph, :Class, :group_object)) == [:member_object]
        end
        @testset "add object members directly to graph" begin
            graph = SpineInterface.empty_entity_group_graph()
            SpineInterface.add_entity_group_member!(graph, :group_entity, :member1)
            @test Graphs.nv(graph) == 2
            @test MetaGraphsNext.haskey(graph, :group_entity)
            @test MetaGraphsNext.haskey(graph, :member1)
            @test Graphs.ne(graph) == 1
            @test MetaGraphsNext.haskey(graph, :member1, :group_entity)
        end
    end
end

function _test_add_parameter_definition()
    @testset "add_parameter_definition!" begin
        @testset "0D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_parameter_definition!(graph, :Class, :Parameter, ParameterValue(2.3))
            vertex = graph[:Class]
            @test vertex.parameter_defaults == Dict(:Parameter => ParameterValue(2.3))
        end
        @testset "1D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_relationship_class!(graph, :Class__, :Class)
            add_parameter_definition!(graph, :Class__, :Parameter, ParameterValue(2.3))
            vertex = graph[:Class__]
            @test vertex.parameter_defaults == Dict(:Parameter => ParameterValue(2.3))
        end
    end
end

function _test_add_parameter_value()
    @testset "add_parameter_value!" begin
        @testset "0D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_parameter_definition!(graph, :Class, :Parameter, ParameterValue(2.3))
            add_entity!(graph, :Class, :Object)
            add_parameter_value!(graph, :Class, :Parameter, ParameterValue(3.2), :Object)
            vertex = graph[:Class]
            @test vertex.parameter_values == Dict(:Object => Dict(:Parameter => ParameterValue(3.2)))
        end
        @testset "1D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_entity!(graph, :Class, :Object)
            add_relationship_class!(graph, :Class__, :Class)
            add_parameter_definition!(graph, :Class__, :Parameter, ParameterValue(2.3))
            relationship_label = add_entity!(graph, :Class__, :Class => :Object)
            add_parameter_value!(graph, :Class__, :Parameter, ParameterValue(3.2), :Class => :Object)
            vertex = graph[:Class__]
            @test vertex.parameter_values == Dict(relationship_label => Dict(:Parameter => ParameterValue(3.2)))
        end
    end
end

function _test_find_objects()
    @testset "find_objects" begin
        @testset "all objects" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            @test isempty(collect(SpineInterface.find_objects(graph, :Class)))
            add_entity!(graph, :Class, :Object)
            @test collect(SpineInterface.find_objects(graph, :Class)) == [:Object]
        end
        @testset "use value filters" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_parameter_definition!(graph, :Class, :Parameter, ParameterValue(nothing))
            add_entity!(graph, :Class, :Object)
            add_parameter_value!(graph, :Class, :Parameter, ParameterValue(2.3), :Object)
            @test collect(SpineInterface.find_objects(graph, :Class, Parameter=2.3)) == [:Object]
            @test isempty(collect(SpineInterface.find_objects(graph, :Class, Parameter=3.2)))
        end
    end
end

function _test_find_relationships()
    @testset "find_relationships" begin
        @testset "simple relationship" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_entity!(graph, :ObjectA, :A)
            add_object_class!(graph, :ObjectB)
            add_entity!(graph, :ObjectB, :B)
            add_relationship_class!(graph, :A__B, :ObjectA, :ObjectB)
            add_entity!(graph, :A__B, :ObjectA => :A, :ObjectB => :B)
            found = SpineInterface.find_relationships(graph, :A__B, anything, anything)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => :A, anything)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, anything, :ObjectB => :B)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => anything, anything)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, anything, :ObjectB => anything)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => :A, :ObjectB => :B)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, (:ObjectA => :A,), :ObjectB => :B)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, (:ObjectA => :A,), (:ObjectB => :B,))
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, (:ObjectA => anything,), (:ObjectB => anything,))
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => :C, anything)
            @test isempty(found)
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => :A, :ObjectB => :D)
            @test isempty(found)
        end
        @testset "multiple relationship options" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_entity!(graph, :Object, :a)
            add_entity!(graph, :Object, :b)
            add_entity!(graph, :Object, :c)
            add_relationship_class!(graph, :Object__, :Object)
            add_entity!(graph, :Object__, :Object => :a)
            add_entity!(graph, :Object__, :Object => :b)
            add_entity!(graph, :Object__, :Object => :c)
            found = SpineInterface.find_relationships(graph, :Object__, anything)
            @test collect(found) == [(:Object => :a,), (:Object => :b,), (:Object => :c,)]
            found = SpineInterface.find_relationships(graph, :Object__, (:Object => :a, :Object => :c))
            @test collect(found) == [(:Object => :a,), (:Object => :c,)]
        end
        @testset "with superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_superclass!(graph, :Object, :ObjectA, :ObjectB)
            add_relationship_class!(graph, :Any__, :Object)
            add_entity!(graph, :ObjectA, :a1)
            add_entity!(graph, :ObjectA, :a2)
            add_entity!(graph, :ObjectB, :b1)
            add_entity!(graph, :ObjectB, :b2)
            add_entity!(graph, :Any__, :ObjectA => :a1)
            add_entity!(graph, :Any__, :ObjectA => :a2)
            add_entity!(graph, :Any__, :ObjectB => :b1)
            add_entity!(graph, :Any__, :ObjectB => :b2)
            found = SpineInterface.find_relationships(graph, :Any__, anything)
            @test sort(collect(found)) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,), (:ObjectB => :b1,), (:ObjectB => :b2,)])
            found = SpineInterface.find_relationships(graph, :Any__, :ObjectA => anything)
            @test sort(collect(found)) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,)])
            found = SpineInterface.find_relationships(graph, :Any__, :ObjectB => anything)
            @test sort(collect(found)) == sort([(:ObjectB => :b1,), (:ObjectB => :b2,)])
            found = SpineInterface.find_relationships(graph, :Any__, (:ObjectA => anything,))
            @test sort(collect(found)) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,)])
        end
        @testset "relationship of relationships" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_object_class!(graph, :ObjectC)
            add_relationship_class!(graph, :A__B, :ObjectA, :ObjectB)
            add_relationship_class!(graph, :B__C, :ObjectB, :ObjectC)
            add_relationship_class!(graph, :AB__BC, :A__B, :B__C)
            add_entity!(graph, :ObjectA, :a1)
            add_entity!(graph, :ObjectA, :a2)
            add_entity!(graph, :ObjectB, :b1)
            add_entity!(graph, :ObjectB, :b2)
            add_entity!(graph, :ObjectC, :c1)
            add_entity!(graph, :A__B, :ObjectA => :a1, :ObjectB => :b1)
            add_entity!(graph, :A__B, :ObjectA => :a1, :ObjectB => :b2)
            add_entity!(graph, :A__B, :ObjectA => :a2, :ObjectB => :b2)
            add_entity!(graph, :B__C, :ObjectB => :b1, :ObjectC => :c2)
            add_entity!(graph, :B__C, :ObjectB => :b2, :ObjectC => :c1)
            add_entity!(graph, :AB__BC, :ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2)
            add_entity!(graph, :AB__BC, :ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2)
            add_entity!(graph, :AB__BC, :ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1)
            found = SpineInterface.find_relationships(graph, :AB__BC, anything, anything, anything, anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
                ])
            @test sort(collect(found)) == expected
            found = SpineInterface.find_relationships(graph, :AB__BC, anything, :ObjectB => :b2, anything, anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
                ])
            @test sort(collect(found)) == expected
            found = SpineInterface.find_relationships(graph, :AB__BC, anything, anything, (:ObjectB => :b2, :ObjectB => :b1), anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
                ])
            @test sort(collect(found)) == expected
            found = SpineInterface.find_relationships(graph, :AB__BC, anything, :ObjectB => :b2, :ObjectB => :b2, anything)
            @test collect(found) == [(:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1)]
            found = SpineInterface.find_relationships(graph, :AB__BC, anything, anything, anything, :ObjectC => anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
                ])
            @test sort(collect(found)) == expected
        end
        @testset "with parameter filters" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_entity!(graph, :Class, :Object)
            add_relationship_class!(graph, :Class__, :Class)
            add_parameter_definition!(graph, :Class__, :Parameter, ParameterValue(nothing))
            add_entity!(graph, :Class__, :Class => :Object)
            add_parameter_value!(graph, :Class__, :Parameter, ParameterValue(2.3), :Class => :Object)
            found = SpineInterface.find_relationships(graph, :Class__, anything, Parameter=2.3)
            @test collect(found) == [(:Class => :Object,)]
            @test isempty(collect(SpineInterface.find_relationships(graph, :Class__, anything, Parameter=3.2)))
        end
    end
end

function _test_find_relationships_compact()
    @testset "find_relationships_compact" begin
        @testset "simple relationship" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_entity!(graph, :ObjectA, :A)
            add_object_class!(graph, :ObjectB)
            add_entity!(graph, :ObjectB, :B)
            add_relationship_class!(graph, :A__B, :ObjectA, :ObjectB)
            add_entity!(graph, :A__B, :ObjectA => :A, :ObjectB => :B)
            found = SpineInterface.find_relationships_compact(graph, :A__B, anything, anything)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => :A, anything)
            @test collect(found) == [(:ObjectB => :B,)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, anything, :ObjectB => :B)
            @test collect(found) == [(:ObjectA => :A,)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => anything, anything)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, anything, :ObjectB => anything)
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => :A, :ObjectB => :B)
            @test isempty(collect(found))
            found = SpineInterface.find_relationships_compact(graph, :A__B, (:ObjectA => :A,), :ObjectB => :B)
            @test isempty(collect(found))
            found = SpineInterface.find_relationships_compact(graph, :A__B, (:ObjectA => :A,), (:ObjectB => :B,))
            @test isempty(collect(found))
            found = SpineInterface.find_relationships_compact(graph, :A__B, (:ObjectA => anything,), (:ObjectB => anything,))
            @test collect(found) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => :C, anything)
            @test isempty(found)
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => :A, :ObjectB => :D)
            @test isempty(found)
        end
        @testset "multiple relationship options" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_entity!(graph, :Object, :a)
            add_entity!(graph, :Object, :b)
            add_entity!(graph, :Object, :c)
            add_relationship_class!(graph, :Object__, :Object)
            add_entity!(graph, :Object__, :Object => :a)
            add_entity!(graph, :Object__, :Object => :b)
            add_entity!(graph, :Object__, :Object => :c)
            found = SpineInterface.find_relationships_compact(graph, :Object__, anything)
            @test collect(found) == [(:Object => :a,), (:Object => :b,), (:Object => :c,)]
        end
        @testset "with superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_superclass!(graph, :Object, :ObjectA, :ObjectB)
            add_relationship_class!(graph, :Any__, :Object)
            add_entity!(graph, :ObjectA, :a1)
            add_entity!(graph, :ObjectA, :a2)
            add_entity!(graph, :ObjectB, :b1)
            add_entity!(graph, :ObjectB, :b2)
            add_entity!(graph, :Any__, :ObjectA => :a1)
            add_entity!(graph, :Any__, :ObjectA => :a2)
            add_entity!(graph, :Any__, :ObjectB => :b1)
            add_entity!(graph, :Any__, :ObjectB => :b2)
            found = SpineInterface.find_relationships_compact(graph, :Any__, anything)
            @test sort(collect(found)) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,), (:ObjectB => :b1,), (:ObjectB => :b2,)])
            found = SpineInterface.find_relationships_compact(graph, :Any__, :ObjectA => anything)
            @test sort(collect(found)) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,)])
            found = SpineInterface.find_relationships_compact(graph, :Any__, :ObjectB => anything)
            @test sort(collect(found)) == sort([(:ObjectB => :b1,), (:ObjectB => :b2,)])
            found = SpineInterface.find_relationships_compact(graph, :Any__, (:ObjectA => anything,))
            @test sort(collect(found)) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,)])
        end
        @testset "relationship of relationships" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :ObjectA)
            add_object_class!(graph, :ObjectB)
            add_object_class!(graph, :ObjectC)
            add_relationship_class!(graph, :A__B, :ObjectA, :ObjectB)
            add_relationship_class!(graph, :B__C, :ObjectB, :ObjectC)
            add_relationship_class!(graph, :AB__BC, :A__B, :B__C)
            add_entity!(graph, :ObjectA, :a1)
            add_entity!(graph, :ObjectA, :a2)
            add_entity!(graph, :ObjectB, :b1)
            add_entity!(graph, :ObjectB, :b2)
            add_entity!(graph, :ObjectC, :c1)
            add_entity!(graph, :A__B, :ObjectA => :a1, :ObjectB => :b1)
            add_entity!(graph, :A__B, :ObjectA => :a1, :ObjectB => :b2)
            add_entity!(graph, :A__B, :ObjectA => :a2, :ObjectB => :b2)
            add_entity!(graph, :B__C, :ObjectB => :b1, :ObjectC => :c2)
            add_entity!(graph, :B__C, :ObjectB => :b2, :ObjectC => :c1)
            add_entity!(graph, :AB__BC, :ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2)
            add_entity!(graph, :AB__BC, :ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2)
            add_entity!(graph, :AB__BC, :ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1)
            found = SpineInterface.find_relationships_compact(graph, :AB__BC, anything, anything, anything, anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
                ])
            @test sort(collect(found)) == expected
            found = SpineInterface.find_relationships_compact(graph, :AB__BC, anything, :ObjectB => :b2, anything, anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectC => :c1),
                ])
            @test sort(collect(found)) == expected
            found = SpineInterface.find_relationships_compact(graph, :AB__BC, anything, anything, (:ObjectB => :b2, :ObjectB => :b1), anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
                ])
            @test sort(collect(found)) == expected
            found = SpineInterface.find_relationships_compact(graph, :AB__BC, anything, :ObjectB => :b2, :ObjectB => :b2, anything)
            @test collect(found) == [(:ObjectA => :a2, :ObjectC => :c1)]
            found = SpineInterface.find_relationships_compact(graph, :AB__BC, anything, anything, anything, :ObjectC => anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
                ])
            @test sort(collect(found)) == expected
        end
        @testset "with parameter filters" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_entity!(graph, :Class, :Object)
            add_relationship_class!(graph, :Class__, :Class)
            add_parameter_definition!(graph, :Class__, :Parameter, ParameterValue(nothing))
            add_entity!(graph, :Class__, :Class => :Object)
            add_parameter_value!(graph, :Class__, :Parameter, ParameterValue(2.3), :Class => :Object)
            found = SpineInterface.find_relationships_compact(graph, :Class__, anything, Parameter=2.3)
            @test collect(found) == [(:Class => :Object,)]
            @test isempty(collect(SpineInterface.find_relationships_compact(graph, :Class__, anything, Parameter=3.2)))
        end
    end
end

function _test_has_relationship()
    @testset "has_relationship" begin
        @testset "from emtpy graph" begin
            graph = SpineInterface.empty_relationship_graph(2)
            @test !SpineInterface.has_relationship(graph, :cat => :garfield, :fish => :nemo)
        end
        @testset "simple cases" begin
            graph = SpineInterface.empty_relationship_graph(2)
            SpineInterface.add_relationship!(graph, :Class1 => :Object11, :Class2 => :Object21)
            @test SpineInterface.has_relationship(graph, :Class1 => :Object11, :Class2 => :Object21)
            @test !SpineInterface.has_relationship(graph, :Class1 => :Object11, :Class2 => :ObjectX)
            @test !SpineInterface.has_relationship(graph, :Class1 => :ObjectX, :Class2 => :Object21)
            @test !SpineInterface.has_relationship(graph, :Class2 => :Object21, :Class1 => :Object11)
        end
        @testset "multiple relationships in graph" begin
            graph = SpineInterface.empty_relationship_graph(2)
            SpineInterface.add_relationship!(graph, :Class1 => :Object11, :Class2 => :Object21)
            SpineInterface.add_relationship!(graph, :Class1 => :Object11, :Class2 => :Object22)
            SpineInterface.add_relationship!(graph, :Class1 => :Object12, :Class2 => :Object21)
            @test SpineInterface.has_relationship(graph, :Class1 => :Object11, :Class2 => :Object21)
            @test SpineInterface.has_relationship(graph, :Class1 => :Object11, :Class2 => :Object22)
            @test SpineInterface.has_relationship(graph, :Class1 => :Object12, :Class2 => :Object21)
            @test !SpineInterface.has_relationship(graph, :Class1 => :Object12, :Class2 => :Object22)
        end
    end
end

function _test_add_relationship()
    @testset "add_relationship!" begin
        @testset "same atom at both dimensions" begin
            graph = SpineInterface.empty_relationship_graph(2)
            label = SpineInterface.add_relationship!(graph, :Class => :Object, :Class => :Object)
            @test Graphs.nv(graph) == 2
            @test Graphs.ne(graph) == 1
            @test MetaGraphsNext.haskey(graph, label)
            @test MetaGraphsNext.haskey(graph, :Class => :Object)
            @test MetaGraphsNext.haskey(graph, :Class => :Object, label)
            @test graph[:Class => :Object, label] == [1, 2]
        end
    end
end

function _test_relationship_atoms_iterator()
    @testset "RelationshipAtoms" begin
        @testset "1D relationship" begin
            graph = SpineInterface.empty_relationship_graph(1)
            relationship_label = SpineInterface.add_relationship!(graph, :ObjectClass => :Object)
            iterator = SpineInterface.RelationshipAtoms(graph, relationship_label)
            @test Tuple(iterator) == (:ObjectClass => :Object,)
        end
        @testset "2D relationship" begin
            graph = SpineInterface.empty_relationship_graph(2)
            relationship_label = SpineInterface.add_relationship!(graph, :Class1 => :Object1, :Class2 => :Object2)
            iterator = SpineInterface.RelationshipAtoms(graph, relationship_label)
            @test Tuple(iterator) == (:Class1 => :Object1, :Class2 => :Object2)
        end
        @testset "2D self-relationship" begin
            graph = SpineInterface.empty_relationship_graph(2)
            relationship_label = SpineInterface.add_relationship!(graph, :Class => :Object, :Class => :Object)
            iterator = SpineInterface.RelationshipAtoms(graph, relationship_label)
            @test Tuple(iterator) == (:Class => :Object, :Class => :Object)
        end
    end
end

function _test_all_atom_tuples()
    @testset "all_atom_tuples" begin
        graph = SpineInterface.empty_relationship_graph(3)
        @test isempty(collect(SpineInterface.all_atom_tuples(graph, ())))
        label1 = SpineInterface.add_relationship!(graph, :Class1 => :o11, :Class2 => :o21, :Class3 => :o31)
        @test collect(SpineInterface.all_atom_tuples(graph, [label1])) == [(:Class1 => :o11, :Class2 => :o21, :Class3 => :o31)]
        label2 = SpineInterface.add_relationship!(graph, :Class1 => :o12, :Class2 => :o22, :Class3 => :o32)
        expected = [
            (:Class1 => :o11, :Class2 => :o21, :Class3 => :o31),
            (:Class1 => :o12, :Class2 => :o22, :Class3 => :o32),
            ]
        @test sort(collect(SpineInterface.all_atom_tuples(graph, [label1, label2]))) == sort(expected)
    end
end

function _test_atom_passes_selection()
    @testset "atom_passes_selection" begin
        @test SpineInterface.atom_passes_selection(:Class => :Object, :Class => anything)
        @test SpineInterface.atom_passes_selection(:Class => :Object, :Class => :Object)
        @test SpineInterface.atom_passes_selection(:Class => :Object, anything)
        @test !SpineInterface.atom_passes_selection(:Class => :Object, :NoClass => anything)
        @test !SpineInterface.atom_passes_selection(:Class => :Object, :Class => :Subject)
        @test !SpineInterface.atom_passes_selection(:Class => :Object, :NoClass => :Object)
    end
end

function _test_selected_relationships_iterator()
    @testset "SelectedRelationships" begin
        @testset "simple relationship" begin
            graph = SpineInterface.empty_relationship_graph(1)
            relationship_label = SpineInterface.add_relationship!(graph, :Class => :A)
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (anything,))
            @test collect(iterator) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (:Class => anything,))
            @test collect(iterator) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (:Class => :A,))
            @test collect(iterator) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], ((:Class => :A,),))
            @test collect(iterator) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], ((:Class => :A, :NoClass => :B)))
            @test collect(iterator) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (:NoClass => anything,))
            @test collect(iterator) == []
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (:Class => :None,))
            @test collect(iterator) == []
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], ((:Class => :None,),))
            @test collect(iterator) == []
        end
    end
end

function _test_add_time_slice_pair()
    @testset "add_time_slice_pair!" begin
        @testset "add one pair" begin
            entity_class_graph = empty_entity_class_graph()
            add_object_class!(entity_class_graph, :block)
            add_entity!(entity_class_graph, :block, :block1)
            add_entity!(entity_class_graph, :block, :block2)
            block_class = ObjectClass(:block, entity_class_graph)
            Y = Bind()
            classes = SpineInterface._getproperty!(Y, :_spine_object_classes, Dict{Symbol,ObjectClass}())
            SpineInterface._add_binding!(Y, classes, :block, block_class, false)
            block1 = Y.block.objects[:block1]
            block2 = Y.block.objects[:block2]
            first_slice = TimeSlice(DateTime("2026-05-05T14:00:00.0"), DateTime("2026-05-05T15:00:00.0"), 1.0, [block1])
            second_slice = TimeSlice(DateTime("2026-05-06T14:00:00.0"), DateTime("2026-05-06T15:00:00.0"), 1.0, [block2])
            graph = SpineInterface.empty_time_slice_graph()
            SpineInterface.add_time_slice_pair!(graph, first_slice, second_slice)
            @test Graphs.nv(graph) == 2
            @test Graphs.ne(graph) == 1
            @test isnothing(graph[first_slice, second_slice])
        end
    end
end

@testset "graphs" begin
    _test_empty_entity_class_graph()
    _test_add_object_class()
    _test_add_relationship_class()
    _test_add_superclass()
    _test_dimensionality()
    _test_dimensions_iterator()
    _test_resolve_atomic_dimension_choices()
    _test_has_entity()
    _test_add_entity()
    _test_add_parameter_definition()
    _test_add_parameter_value()
    _test_find_objects()
    _test_find_relationships()
    _test_find_relationships_compact()
    _test_has_relationship()
    _test_add_relationship()
    _test_relationship_atoms_iterator()
    _test_all_atom_tuples()
    _test_atom_passes_selection()
    _test_selected_relationships_iterator()
    _test_add_time_slice_pair()
    _test_add_entity_group_member()
end
