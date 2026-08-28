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

function _test_add_entity_class()
    @testset "add_entity_class!" begin
        graph = empty_entity_class_graph()
        add_entity_class!(graph, :A)
        @test Graphs.nv(graph) == 1
        @test SpineInterface.is_object_class(graph, :A)
        add_entity_class!(graph, :B)
        @test Graphs.nv(graph) == 2
        @test SpineInterface.is_object_class(graph, :B)
        add_entity_class!(graph, :A__B, :A, :B)
        @test Graphs.nv(graph) == 3
        @test SpineInterface.is_relationship_class(graph, :A__B)
        @test collect(SpineInterface.Dimensions(graph, :A__B)) == [:A, :B]
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

function _test_class_labels()
    @testset "class_labels" begin
        @testset "empty graph" begin
            @test isempty(collect(class_labels(empty_entity_class_graph())))
        end
        @testset "graph with classes" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_relationship_class!(graph, :A__B, :A, :B)
            add_relationship_class!(graph, :A__A, :A, :A)
            @test sort(collect(class_labels(graph))) == sort([:A, :B, :A__A, :A__B])
        end
    end
end

function _test_classes_in_dependency_order_iterator()
    @testset "ClassesInDependencyOrder" begin
        @testset "object classes come before relationship classes" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_relationship_class!(graph, :A__B, :A, :B)
            dependants = Set([:A, :B])
            iter = SpineInterface.ClassesInDependencyOrder(graph)
            for label in Iterators.take(iter, 2)
                @test label in dependants
                delete!(dependants, label)
            end
            @test collect(Iterators.drop(iter, 2)) == [:A__B]
        end
        @testset "subclasses come before their superclasses" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_superclass!(graph, :super, :A, :B)
            dependants = Set([:A, :B])
            iter = SpineInterface.ClassesInDependencyOrder(graph)
            for label in Iterators.take(iter, 2)
                @test label in dependants
                delete!(dependants, label)
            end
            @test collect(Iterators.drop(iter, 2)) == [:super]
        end
        @testset "multilevel hierarchy" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_object_class!(graph, :C)
            add_superclass!(graph, :super, :A, :B)
            add_relationship_class!(graph, :AB__AB, :super, :super)
            add_relationship_class!(graph, :AB__AB__C, :AB__AB, :C)
            dependees = Dict([
                :A => Set([:super, :AB__AB, :AB__AB__C]),
                :B => Set([:super, :AB__AB, :AB__AB__C]),
                :C => Set([:AB__AB__C]),
                :super => Set([:AB__AB, :AB__AB__C]),
                :AB__AB => Set([:AB__AB__C]),
                :AB__AB__C => Set(),
            ])
            classes = collect(SpineInterface.ClassesInDependencyOrder(graph))
            for (i, label) in enumerate(classes)
                expected = dependees[label]
                for label in classes[(i + 1):end]
                    if label in expected
                        delete!(expected, label)
                    end
                end
                @test isempty(expected)
            end
        end
    end
end

function _test_is_object_class()
    @testset "is_object_class" begin
        graph = empty_entity_class_graph()
        add_object_class!(graph, :A)
        add_relationship_class!(graph, :A__, :A)
        add_superclass!(graph, :super, :A)
        @test is_object_class(graph, :A)
        @test !is_object_class(graph, :A__)
        @test !is_object_class(graph, :super)
    end
end

function _test_is_relationship_class()
    @testset "is_relationship_class" begin
        graph = empty_entity_class_graph()
        add_object_class!(graph, :A)
        add_relationship_class!(graph, :A__, :A)
        add_superclass!(graph, :super, :A)
        @test !is_relationship_class(graph, :A)
        @test is_relationship_class(graph, :A__)
        @test !is_relationship_class(graph, :super)
    end
end

function _test_is_superclass()
    @testset "is_superclass" begin
        graph = empty_entity_class_graph()
        add_object_class!(graph, :A)
        add_object_class!(graph, :B)
        add_relationship_class!(graph, :A__B, :A, :B)
        add_superclass!(graph, :super, :A, :B)
        @test is_superclass(graph, :super)
        @test !is_superclass(graph, :A)
        @test !is_superclass(graph, :B)
        @test !is_superclass(graph, :A__B)
    end
end

function _test_is_subclass_of()
    @testset "is_subclass_of" begin
        graph = empty_entity_class_graph()
        add_object_class!(graph, :A)
        add_object_class!(graph, :B)
        add_relationship_class!(graph, :A__B, :A, :B)
        add_superclass!(graph, :super, :A, :B)
        @test is_subclass_of(graph, :A, :super)
        @test is_subclass_of(graph, :B, :super)
        @test !is_subclass_of(graph, :A, :B)
        @test !is_subclass_of(graph, :A, :A__B)
    end
end

function _test_subclasses()
    @testset "subclasses" begin
        graph = empty_entity_class_graph()
        add_object_class!(graph, :A)
        add_object_class!(graph, :B)
        add_relationship_class!(graph, :A__B, :A, :B)
        add_superclass!(graph, :super, :A, :B)
        @test sort(collect(subclasses(graph, :super))) == sort([:A, :B])
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

function _test_atomic_dimensions()
    @testset "atomic_dimensions" begin
        @testset "just an object" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O)
            @test SpineInterface.atomic_dimensions(graph, :O) == [[:O]]
        end
        @testset "simple relationship class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O)
            add_object_class!(graph, :P)
            add_relationship_class!(graph, :O__P, :O, :P)
            @test SpineInterface.atomic_dimensions(graph, :O__P) == [[:O, :P]]
        end
        @testset "nested relationship classes" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O)
            add_object_class!(graph, :P)
            add_object_class!(graph, :Q)
            add_relationship_class!(graph, :O__P, :O, :P)
            add_relationship_class!(graph, :P__Q, :P, :Q)
            add_relationship_class!(graph, :O__P__P__Q, :O__P, :P__Q)
            @test SpineInterface.atomic_dimensions(graph, :O__P__P__Q) == [[:O, :P, :P, :Q]]
        end
        @testset "superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O)
            add_object_class!(graph, :P)
            add_superclass!(graph, :S, :O, :P)
            @test SpineInterface.atomic_dimensions(graph, :S) == [[:O], [:P]]
        end
        @testset "relationships and superclasses" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O)
            add_object_class!(graph, :P)
            add_relationship_class!(graph, :O__P, :O, :P)
            add_relationship_class!(graph, :P__O, :P, :O)
            add_superclass!(graph, :S, :O__P, :P__O)
            add_relationship_class!(graph, :S__S, :S, :S)
            @test sort(SpineInterface.atomic_dimensions(graph, :S__S)) ==
                  sort([[:O, :P, :O, :P], [:O, :P, :P, :O], [:P, :O, :O, :P], [:P, :O, :P, :O]])
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

function _test_atomic_dimensionality()
    @testset "atomic_dimensionality" begin
        @testset "object class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            @test SpineInterface.atomic_dimensionality(graph, :Object) == 0
        end
        @testset "relationship class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_object_class!(graph, :C)
            add_object_class!(graph, :D)
            add_relationship_class!(graph, :A__B, :A, :B)
            add_relationship_class!(graph, :C__D, :C, :D)
            add_relationship_class!(graph, :AB__CD, :A__B, :C__D)
            @test SpineInterface.atomic_dimensionality(graph, :A__B) == 2
            @test SpineInterface.atomic_dimensionality(graph, :C__D) == 2
            @test SpineInterface.atomic_dimensionality(graph, :AB__CD) == 4
        end
        @testset "superclass of relationship classes" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_object_class!(graph, :C)
            add_object_class!(graph, :D)
            add_relationship_class!(graph, :A__B, :A, :B)
            add_relationship_class!(graph, :C__D, :C, :D)
            add_superclass!(graph, :Any__Any, :A__B, :C__D)
            @test SpineInterface.atomic_dimensionality(graph, :Any__Any) == 2
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

function _test_subclass_vertex_with_entity()
    @testset "subclass_vertex_with_entity" begin
        @testset "subclass is object class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :B, :b)
            add_superclass!(graph, :Any, :A, :B)
            @test SpineInterface.subclass_vertex_with_entity(graph[:Any], :a) === graph[:A]
            @test SpineInterface.subclass_vertex_with_entity(graph[:Any], :b) === graph[:B]
            @test isnothing(SpineInterface.subclass_vertex_with_entity(graph[:Any], :something_else))
        end
        @testset "subclass is relationship class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_object_class!(graph, :C)
            add_object_class!(graph, :D)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :B, :b)
            add_entity!(graph, :C, :c)
            add_entity!(graph, :D, :d)
            add_relationship_class!(graph, :A__B, :A, :B)
            add_relationship_class!(graph, :C__D, :C, :D)
            add_entity!(graph, :A__B, :A => :a, :B => :b)
            add_entity!(graph, :C__D, :C => :c, :D => :d)
            add_superclass!(graph, :AB_or_CD, :A__B, :C__D)
            @test SpineInterface.subclass_vertex_with_entity(graph[:AB_or_CD], :A => :a, :B => :b) === graph[:A__B]
            @test SpineInterface.subclass_vertex_with_entity(graph[:AB_or_CD], :C => :c, :D => :d) === graph[:C__D]
            @test isnothing(SpineInterface.subclass_vertex_with_entity(graph[:AB_or_CD], :A => :not_in_A, :B => :b))
        end
        @testset "subclass is superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_object_class!(graph, :C)
            add_object_class!(graph, :D)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :B, :b)
            add_entity!(graph, :C, :c)
            add_entity!(graph, :D, :d)
            add_superclass!(graph, :A_or_B, :A, :B)
            add_superclass!(graph, :C_or_D, :C, :D)
            add_superclass!(graph, :Any, :A_or_B, :C_or_D)
            @test SpineInterface.subclass_vertex_with_entity(graph[:Any], :a) === graph[:A]
            @test SpineInterface.subclass_vertex_with_entity(graph[:Any], :b) === graph[:B]
            @test SpineInterface.subclass_vertex_with_entity(graph[:Any], :c) === graph[:C]
            @test SpineInterface.subclass_vertex_with_entity(graph[:Any], :d) === graph[:D]
        end
    end
end

function _test_entities()
    @testset "entities" begin
        @testset "0D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_entity!(graph, :Object, :a)
            @test collect(entities(graph, :Object)) == [:a]
        end
        @testset "2D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_entity!(graph, :A, :a)
            add_object_class!(graph, :B)
            add_entity!(graph, :B, :b)
            add_relationship_class!(graph, :A__B, :A, :B)
            add_entity!(graph, :A__B, :A => :a, :B => :b)
            @test collect(entities(graph, :A__B)) == [(:A => :a, :B => :b)]
        end
        @testset "superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_entity!(graph, :A, :a)
            add_object_class!(graph, :B)
            add_entity!(graph, :B, :b)
            add_superclass!(graph, :A_or_B, :A, :B)
            @test sort(collect(entities(graph, :A_or_B))) == sort([:a, :b])
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
            add_parameter_definition!(graph, :Class, :Parameter, 2.3)
            vertex = graph[:Class]
            @test vertex.parameter_defaults == Dict(:Parameter => ParameterValue(2.3))
        end
        @testset "1D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_relationship_class!(graph, :Class__, :Class)
            add_parameter_definition!(graph, :Class__, :Parameter, 2.3)
            vertex = graph[:Class__]
            @test vertex.parameter_defaults == Dict(:Parameter => ParameterValue(2.3))
        end
        @testset "default value is nothing by default" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_parameter_definition!(graph, :Class, :Parameter)
            vertex = graph[:Class]
            @test vertex.parameter_defaults == Dict(:Parameter => parameter_value(nothing))
        end
    end
end

function _test_set_parameter_value()
    @testset "set_parameter_value!" begin
        @testset "0D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_parameter_definition!(graph, :Class, :Parameter, 2.3)
            add_entity!(graph, :Class, :Object)
            set_parameter_value!(graph, :Class, :Parameter, :Object, 3.2)
            vertex = graph[:Class]
            @test vertex.parameter_values == Dict(:Object => Dict(:Parameter => ParameterValue(3.2)))
        end
        @testset "1D entity class" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_entity!(graph, :Class, :Object)
            add_relationship_class!(graph, :Class__, :Class)
            add_parameter_definition!(graph, :Class__, :Parameter, 2.3)
            relationship_label = add_entity!(graph, :Class__, :Class => :Object)
            set_parameter_value!(graph, :Class__, :Parameter, :Class => :Object, 3.2)
            vertex = graph[:Class__]
            @test vertex.parameter_values == Dict(relationship_label => Dict(:Parameter => ParameterValue(3.2)))
        end
    end
end

function _test_concrete_subclass_labels_iterator()
    @testset "ConcreteSubclassLabels" begin
        @testset "simple superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O)
            add_superclass!(graph, :S, :O)
            iter = SpineInterface.ConcreteSubclassLabels(graph, :S)
            @test collect(iter) == [:O]
        end
        @testset "superclass of two object classes" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O1)
            add_object_class!(graph, :O2)
            add_superclass!(graph, :S, :O1, :O2)
            iter = SpineInterface.ConcreteSubclassLabels(graph, :S)
            @test sort(collect(iter)) == sort([:O1, :O2])
        end
        @testset "relationship class as subclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O)
            add_relationship_class!(graph, :R1, :O)
            add_relationship_class!(graph, :R2, :O)
            add_superclass!(graph, :S, :R1, :R2)
            iter = SpineInterface.ConcreteSubclassLabels(graph, :S)
            @test sort(collect(iter)) == sort([:R1, :R2])
        end
        @testset "superclass of superclass" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O)
            add_superclass!(graph, :S1, :O)
            add_superclass!(graph, :S2, :S1)
            iter = SpineInterface.ConcreteSubclassLabels(graph, :S2)
            @test collect(iter) == [:O]
        end
        @testset "multiple superclasses of superclasses" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :O1)
            add_object_class!(graph, :O2)
            add_superclass!(graph, :S11, :O1)
            add_superclass!(graph, :S12, :O2)
            add_superclass!(graph, :S, :S11, :S12)
            iter = SpineInterface.ConcreteSubclassLabels(graph, :S)
            @test sort(collect(iter)) == sort([:O1, :O2])
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
            set_parameter_value!(graph, :Class, :Parameter, :Object, ParameterValue(2.3))
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
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => :A, anything)
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, anything, :ObjectB => :B)
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => anything, anything)
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, anything, :ObjectB => anything)
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => :A, :ObjectB => :B)
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, (:ObjectA => :A,), :ObjectB => :B)
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, (:ObjectA => :A,), (:ObjectB => :B,))
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, (:ObjectA => anything,), (:ObjectB => anything,))
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => :C, anything)
            @test isempty(Tuple.(found))
            found = SpineInterface.find_relationships(graph, :A__B, :ObjectA => :A, :ObjectB => :D)
            @test isempty(Tuple.(found))
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
            @test collect(Tuple.(found)) == [(:Object => :a,), (:Object => :b,), (:Object => :c,)]
            found = SpineInterface.find_relationships(graph, :Object__, (:Object => :a, :Object => :c))
            @test collect(Tuple.(found)) == [(:Object => :a,), (:Object => :c,)]
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
            @test sort(collect(Tuple.(found))) ==
                  sort([(:ObjectA => :a1,), (:ObjectA => :a2,), (:ObjectB => :b1,), (:ObjectB => :b2,)])
            found = SpineInterface.find_relationships(graph, :Any__, :ObjectA => anything)
            @test sort(collect(Tuple.(found))) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,)])
            found = SpineInterface.find_relationships(graph, :Any__, :ObjectB => anything)
            @test sort(collect(Tuple.(found))) == sort([(:ObjectB => :b1,), (:ObjectB => :b2,)])
            found = SpineInterface.find_relationships(graph, :Any__, (:ObjectA => anything,))
            @test sort(collect(Tuple.(found))) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,)])
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
            @test sort(collect(Tuple.(found))) == expected
            found = SpineInterface.find_relationships(graph, :AB__BC, anything, :ObjectB => :b2, anything, anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
            ])
            @test sort(collect(Tuple.(found))) == expected
            found = SpineInterface.find_relationships(
                graph,
                :AB__BC,
                anything,
                anything,
                (:ObjectB => :b2, :ObjectB => :b1),
                anything,
            )
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
            ])
            @test sort(collect(Tuple.(found))) == expected
            found =
                SpineInterface.find_relationships(graph, :AB__BC, anything, :ObjectB => :b2, :ObjectB => :b2, anything)
            @test collect(Tuple.(found)) == [(:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1)]
            found =
                SpineInterface.find_relationships(graph, :AB__BC, anything, anything, anything, :ObjectC => anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
            ])
            @test sort(collect(Tuple.(found))) == expected
        end
        @testset "with parameter filters" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_entity!(graph, :Class, :Object)
            add_relationship_class!(graph, :Class__, :Class)
            add_parameter_definition!(graph, :Class__, :Parameter, ParameterValue(nothing))
            add_entity!(graph, :Class__, :Class => :Object)
            set_parameter_value!(graph, :Class__, :Parameter, :Class => :Object, ParameterValue(2.3))
            found = SpineInterface.find_relationships(graph, :Class__, anything, Parameter=2.3)
            @test collect(Tuple.(found)) == [(:Class => :Object,)]
            @test isempty(collect(SpineInterface.find_relationships(graph, :Class__, anything, Parameter=3.2)))
        end
        @testset "2D relationship with parameter filters" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :unit)
            add_entity!(graph, :unit, :coal)
            add_entity!(graph, :unit, :coal_chp)
            add_object_class!(graph, :node)
            add_entity!(graph, :node, :east)
            add_entity!(graph, :node, :west)
            add_relationship_class!(graph, :node__unit, :node, :unit)
            add_parameter_definition!(graph, :node__unit, :cost, parameter_value(nothing))
            entity = add_entity!(graph, :node__unit, :node => :east, :unit => :coal)
            set_parameter_value!(graph, :node__unit, :cost, entity, parameter_value(5.0))
            entity = add_entity!(graph, :node__unit, :node => :west, :unit => :coal)
            set_parameter_value!(graph, :node__unit, :cost, entity, parameter_value(6.0))
            entity = add_entity!(graph, :node__unit, :node => :east, :unit => :coal_chp)
            set_parameter_value!(graph, :node__unit, :cost, entity, parameter_value(4.0))
            entity = add_entity!(graph, :node__unit, :node => :west, :unit => :coal_chp)
            set_parameter_value!(graph, :node__unit, :cost, entity, parameter_value(2.0))
            @test sort(collect(Tuple.(find_relationships(graph, :node__unit, :node => :west, anything; cost=2.0)))) ==
                  [(:node => :west, :unit => :coal_chp)]
        end
        @testset "string value in parameter filter" begin
            data = empty_entity_class_graph();
            add_object_class!(data, :actor);
            add_object_class!(data, :film);
            add_entity!(data, :actor, :Phoenix);
            add_entity!(data, :actor, :Johansson);
            add_entity!(data, :film, :Her);
            add_entity!(data, :film, :Joker);
            add_relationship_class!(data, :actor__film, :actor, :film);
            add_entity!(data, :actor__film, :actor => :Phoenix, :film => :Joker);
            add_entity!(data, :actor__film, :actor => :Phoenix, :film => :Her);
            add_entity!(data, :actor__film, :actor => :Johansson, :film => :Her);
            add_parameter_definition!(data, :actor__film, :character_name);
            set_parameter_value!(data, :actor__film, :character_name, :actor => :Phoenix, :film => :Her, "Theodore");
            @test collect(Tuple.(find_relationships(data, :actor__film, (:actor => :Phoenix, :actor => :Johansson), anything; character_name=:Theodore))) == [(:actor => :Phoenix, :film => :Her)]
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
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => :A, anything)
            @test collect(Tuple.(found)) == [(:ObjectB => :B,)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, anything, :ObjectB => :B)
            @test collect(Tuple.(found)) == [(:ObjectA => :A,)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => anything, anything)
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, anything, :ObjectB => anything)
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => :A, :ObjectB => :B)
            @test isempty(collect(Tuple.(found)))
            found = SpineInterface.find_relationships_compact(graph, :A__B, (:ObjectA => :A,), :ObjectB => :B)
            @test isempty(collect(Tuple.(found)))
            found = SpineInterface.find_relationships_compact(graph, :A__B, (:ObjectA => :A,), (:ObjectB => :B,))
            @test isempty(collect(Tuple.(found)))
            found = SpineInterface.find_relationships_compact(
                graph,
                :A__B,
                (:ObjectA => anything,),
                (:ObjectB => anything,),
            )
            @test collect(Tuple.(found)) == [(:ObjectA => :A, :ObjectB => :B)]
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => :C, anything)
            @test isempty(Tuple.(found))
            found = SpineInterface.find_relationships_compact(graph, :A__B, :ObjectA => :A, :ObjectB => :D)
            @test isempty(Tuple.(found))
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
            @test collect(Tuple.(found)) == [(:Object => :a,), (:Object => :b,), (:Object => :c,)]
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
            @test sort(collect(Tuple.(found))) ==
                  sort([(:ObjectA => :a1,), (:ObjectA => :a2,), (:ObjectB => :b1,), (:ObjectB => :b2,)])
            found = SpineInterface.find_relationships_compact(graph, :Any__, :ObjectA => anything)
            @test sort(collect(Tuple.(found))) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,)])
            found = SpineInterface.find_relationships_compact(graph, :Any__, :ObjectB => anything)
            @test sort(collect(Tuple.(found))) == sort([(:ObjectB => :b1,), (:ObjectB => :b2,)])
            found = SpineInterface.find_relationships_compact(graph, :Any__, (:ObjectA => anything,))
            @test sort(collect(Tuple.(found))) == sort([(:ObjectA => :a1,), (:ObjectA => :a2,)])
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
            @test sort(collect(Tuple.(found))) == expected
            found =
                SpineInterface.find_relationships_compact(graph, :AB__BC, anything, :ObjectB => :b2, anything, anything)
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectC => :c1),
            ])
            @test sort(collect(Tuple.(found))) == expected
            found = SpineInterface.find_relationships_compact(
                graph,
                :AB__BC,
                anything,
                anything,
                (:ObjectB => :b2, :ObjectB => :b1),
                anything,
            )
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
            ])
            @test sort(collect(Tuple.(found))) == expected
            found = SpineInterface.find_relationships_compact(
                graph,
                :AB__BC,
                anything,
                :ObjectB => :b2,
                :ObjectB => :b2,
                anything,
            )
            @test collect(Tuple.(found)) == [(:ObjectA => :a2, :ObjectC => :c1)]
            found = SpineInterface.find_relationships_compact(
                graph,
                :AB__BC,
                anything,
                anything,
                anything,
                :ObjectC => anything,
            )
            expected = sort([
                (:ObjectA => :a1, :ObjectB => :b1, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a1, :ObjectB => :b2, :ObjectB => :b1, :ObjectC => :c2),
                (:ObjectA => :a2, :ObjectB => :b2, :ObjectB => :b2, :ObjectC => :c1),
            ])
            @test sort(collect(Tuple.(found))) == expected
        end
        @testset "with parameter filters" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Class)
            add_entity!(graph, :Class, :Object)
            add_relationship_class!(graph, :Class__, :Class)
            add_parameter_definition!(graph, :Class__, :Parameter, ParameterValue(nothing))
            add_entity!(graph, :Class__, :Class => :Object)
            set_parameter_value!(graph, :Class__, :Parameter, :Class => :Object, ParameterValue(2.3))
            found = SpineInterface.find_relationships_compact(graph, :Class__, anything, Parameter=2.3)
            @test collect(Tuple.(found)) == [(:Class => :Object,)]
            @test isempty(
                collect(Tuple.(SpineInterface.find_relationships_compact(graph, :Class__, anything, Parameter=3.2))),
            )
        end
    end
end

function _test_delete_future_rophan_dependee_vertices()
    @testset "delete_future_orphan_dependee_vertices!" begin
        @testset "shared member is not deleted" begin
            graph = SpineInterface.empty_entity_group_graph()
            add_entity_group_member!(graph, :group1, :shared_member)
            add_entity_group_member!(graph, :group1, :single_member1)
            add_entity_group_member!(graph, :group2, :shared_member)
            add_entity_group_member!(graph, :group2, :single_member2)
            @test Graphs.nv(graph) == 5
            SpineInterface.delete_future_orphan_dependee_vertices!(graph, :group1)
            @test sort(collect(MetaGraphsNext.labels(graph))) ==
                  sort([:group1, :group2, :shared_member, :single_member2])
            SpineInterface.delete_future_orphan_dependee_vertices!(graph, :group2)
            @test sort(collect(MetaGraphsNext.labels(graph))) == sort([:group1, :group2, :shared_member])
        end
    end
end

function _test_delete_future_rophan_dependant_vertices()
    @testset "delete_future_orphan_dependant_vertices!" begin
        @testset "vertices with edges are not deleted" begin
            graph = SpineInterface.empty_entity_group_graph()
            add_entity_group_member!(graph, :small_group, :shared_member)
            add_entity_group_member!(graph, :large_group, :shared_member)
            add_entity_group_member!(graph, :large_group, :single_member)
            @test Graphs.nv(graph) == 4
            SpineInterface.delete_future_orphan_dependant_vertices!(graph, :shared_member)
            @test sort(collect(MetaGraphsNext.labels(graph))) == sort([:large_group, :shared_member, :single_member])
            SpineInterface.delete_future_orphan_dependant_vertices!(graph, :single_member)
            @test sort(collect(MetaGraphsNext.labels(graph))) == sort([:large_group, :shared_member, :single_member])
        end
    end
end

function _test_class_for_object()
    @testset "class_for_object" begin
        graph = empty_entity_class_graph()
        add_object_class!(graph, :A)
        add_object_class!(graph, :B)
        add_entity!(graph, :A, :a)
        add_entity!(graph, :B, :b)
        add_relationship_class!(graph, :A__B, :A, :B)
        add_relationship_class!(graph, :B__A, :B, :A)
        @test SpineInterface.class_for_object(graph, :A__B, :a, 1) == :A
        @test SpineInterface.class_for_object(graph, :A__B, :b, 2) == :B
        @test SpineInterface.class_for_object(graph, :B__A, :a, 2) == :A
        @test SpineInterface.class_for_object(graph, :B__A, :b, 1) == :B
        @test_throws ErrorException SpineInterface.class_for_object(graph, :A__B, :a, 2)
        @test_throws ErrorException SpineInterface.class_for_object(graph, :A__B, :no_entity, 1)
        add_superclass!(graph, :AB_or_BA, :A__B, :B__A)
        add_relationship_class!(graph, :R__R, :AB_or_BA, :AB_or_BA)
        @test SpineInterface.class_for_object(graph, :R__R, :a, 1) == :A
        @test SpineInterface.class_for_object(graph, :R__R, :a, 2) == :A
        @test SpineInterface.class_for_object(graph, :R__R, :a, 3) == :A
        @test SpineInterface.class_for_object(graph, :R__R, :a, 4) == :A
        @test SpineInterface.class_for_object(graph, :R__R, :b, 1) == :B
        @test SpineInterface.class_for_object(graph, :R__R, :b, 2) == :B
        @test SpineInterface.class_for_object(graph, :R__R, :b, 3) == :B
        @test SpineInterface.class_for_object(graph, :R__R, :b, 4) == :B
    end
end

function _test_remove_entity()
    @testset "remove_entity!" begin
        @testset "0D entity" begin
            graph = SpineInterface.empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_parameter_definition!(graph, :Object, :X)
            add_entity!(graph, :Object, :a)
            set_parameter_value!(graph, :Object, :X, :a, 2.3)
            remove_entity!(graph, :Object, :a)
            @test isempty(graph[:Object].entities)
            @test isempty(graph[:Object].parameter_values)
        end
        @testset "0D group member" begin
            graph = SpineInterface.empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_entity!(graph, :Object, :group)
            add_entity!(graph, :Object, :member)
            add_entity_group_member!(graph, :Object, :group, :member)
            remove_entity!(graph, :Object, :member)
            @test graph[:Object].entities == Set([:group])
            @test Graphs.nv(graph[:Object].entity_group_graph) == 0
        end
        @testset "2D entity" begin
            graph = SpineInterface.empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_entity!(graph, :A, :a)
            add_relationship_class!(graph, :A__, :A)
            add_parameter_definition!(graph, :A__, :X)
            add_entity!(graph, :A__, :A => :a)
            set_parameter_value!(graph, :A__, :X, :A => :a, parameter_value(2.3))
            remove_entity!(graph, :A__, :A => :a)
            vertex = graph[:A__]
            @test isempty(vertex.entities)
            @test Graphs.nv(vertex.relationship_graph) == 0
            @test isempty(vertex.parameter_values)
        end
        @testset "superclass" begin
            graph = SpineInterface.empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_entity!(graph, :A, :a)
            add_object_class!(graph, :B)
            add_entity!(graph, :B, :b)
            add_superclass!(graph, :A_or_B, :A, :B)
            remove_entity!(graph, :A_or_B, :a)
            @test isempty(graph[:A].entities)
            @test graph[:B].entities == Set([:b])
            remove_entity!(graph, :A_or_B, :b)
            @test isempty(graph[:B].entities)
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
        @test collect(SpineInterface.all_atom_tuples(graph, [label1])) ==
              [(:Class1 => :o11, :Class2 => :o21, :Class3 => :o31)]
        label2 = SpineInterface.add_relationship!(graph, :Class1 => :o12, :Class2 => :o22, :Class3 => :o32)
        expected =
            [(:Class1 => :o11, :Class2 => :o21, :Class3 => :o31), (:Class1 => :o12, :Class2 => :o22, :Class3 => :o32)]
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
            @test collect(Tuple.(iterator)) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (:Class => anything,))
            @test collect(Tuple.(iterator)) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (:Class => :A,))
            @test collect(Tuple.(iterator)) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], ((:Class => :A,),))
            @test collect(Tuple.(iterator)) == [(:Class => :A,)]
            iterator =
                SpineInterface.SelectedRelationships(graph, [relationship_label], ((:Class => :A, :NoClass => :B)))
            @test collect(Tuple.(iterator)) == [(:Class => :A,)]
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (:NoClass => anything,))
            @test collect(Tuple.(iterator)) == []
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], (:Class => :None,))
            @test collect(Tuple.(iterator)) == []
            iterator = SpineInterface.SelectedRelationships(graph, [relationship_label], ((:Class => :None,),))
            @test collect(Tuple.(iterator)) == []
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
            second_slice =
                TimeSlice(DateTime("2026-05-06T14:00:00.0"), DateTime("2026-05-06T15:00:00.0"), 1.0, [block2])
            graph = SpineInterface.empty_time_slice_graph()
            SpineInterface.add_time_slice_pair!(graph, first_slice, second_slice)
            @test Graphs.nv(graph) == 2
            @test Graphs.ne(graph) == 1
            @test isnothing(graph[first_slice, second_slice])
        end
    end
end

function _test_default_value()
    @testset "default_value" begin
        graph = empty_entity_class_graph()
        add_object_class!(graph, :Object)
        add_parameter_definition!(graph, :Object, :with_default, 2.3)
        @test default_value(graph, :Object, :with_default) == parameter_value(2.3)
    end
end

function _test_find_value()
    @testset "find_value" begin
        @testset "object parameter value" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :Object)
            add_parameter_definition!(graph, :Object, :weight, 2.3)
            add_entity!(graph, :Object, :spoon)
            set_parameter_value!(graph, :Object, :weight, :spoon, 3.2)
            @test find_value(graph, :Object, :weight, :spoon) == parameter_value(3.2)
            @test isnothing(find_value(graph, :Object, :no_such_parameter, :spoon))
            @test_throws KeyError find_value(graph, :Object, :weight, :no_such_entity)
        end
        @testset "relationship parameter value" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_relationship_class!(graph, :A__B, :A, :B)
            add_parameter_definition!(graph, :A__B, :weight, 2.3)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :B, :b)
            add_entity!(graph, :A__B, :A => :a, :B => :b)
            set_parameter_value!(graph, :A__B, :weight, :A => :a, :B => :b, 3.2)
            @test find_value(graph, :A__B, :weight, :A => :a, :B => :b) == parameter_value(3.2)
            @test isnothing(find_value(graph, :A__B, :no_such_parameter, :A => :a, :B => :b))
            @test_throws KeyError find_value(graph, :A__B, :weight, :A => :no_such_entity, :B => :b)
        end
        @testset "subclass parameter value" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_parameter_definition!(graph, :A, :shared)
            add_parameter_definition!(graph, :A, :onlyA)
            add_object_class!(graph, :B)
            add_parameter_definition!(graph, :B, :shared)
            add_parameter_definition!(graph, :B, :onlyB)
            add_superclass!(graph, :A_or_B, :A, :B)
            add_entity!(graph, :A, :a)
            set_parameter_value!(graph, :A, :shared, :a, 1.1)
            set_parameter_value!(graph, :A, :onlyA, :a, 2.2)
            add_entity!(graph, :B, :b)
            set_parameter_value!(graph, :B, :shared, :b, 3.3)
            set_parameter_value!(graph, :B, :onlyB, :b, 4.4)
            @test find_value(graph, :A_or_B, :shared, :a) == parameter_value(1.1)
            @test find_value(graph, :A_or_B, :onlyA, :a) == parameter_value(2.2)
            @test isnothing(find_value(graph, :A_or_B, :onlyB, :a))
            @test find_value(graph, :A_or_B, :shared, :b) == parameter_value(3.3)
            @test find_value(graph, :A_or_B, :onlyB, :b) == parameter_value(4.4)
            @test isnothing(find_value(graph, :A_or_B, :onlyA, :b))
            @test isnothing(find_value(graph, :A_or_B, :no_such_parameter, :a))
        end
    end
end

function _test_value_or_default()
    @testset "value_or_default" begin
        @testset "0D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_parameter_definition!(graph, :A, :X, 2.2)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :A, :b)
            set_parameter_value!(graph, :A, :X, :a, 1.1)
            @test value_or_default(graph, :A, :X, :a) == parameter_value(1.1)
            @test value_or_default(graph, :A, :X, :b) == parameter_value(2.2)
            @test_throws KeyError value_or_default(graph, :A, :X, :c)
        end
        @testset "1D entity" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :A, :b)
            add_relationship_class!(graph, :A__, :A)
            add_parameter_definition!(graph, :A__, :X, 2.2)
            add_entity!(graph, :A__, :A => :a)
            set_parameter_value!(graph, :A__, :X, :A => :a, 1.1)
            add_entity!(graph, :A__, :A => :b)
            @test value_or_default(graph, :A__, :X, :A => :a) == parameter_value(1.1)
            @test value_or_default(graph, :A__, :X, :A => :b) == parameter_value(2.2)
            @test_throws KeyError value_or_default(graph, :A__, :X, :A => :c)
        end
        @testset "subclass parameter value" begin
            graph = empty_entity_class_graph()
            add_object_class!(graph, :A)
            add_object_class!(graph, :B)
            add_parameter_definition!(graph, :B, :X, 2.2)
            add_superclass!(graph, :super, :A, :B)
            add_entity!(graph, :A, :a)
            add_entity!(graph, :B, :b1)
            add_entity!(graph, :B, :b2)
            set_parameter_value!(graph, :B, :X, :b2, 1.1)
            @test value_or_default(graph, :super, :X, :b2) == parameter_value(1.1)
            @test value_or_default(graph, :super, :X, :b1) == parameter_value(2.2)
            @test_throws KeyError value_or_default(graph, :super, :X, :a)
        end
    end
end

function _test_is_group_entity()
    @testset "is_group_entity" begin
        graph = SpineInterface.empty_entity_group_graph()
        add_entity_group_member!(graph, :group, :member)
        @test SpineInterface.is_group_entity(graph, :group)
        @test !SpineInterface.is_group_entity(graph, :member)
    end
end

function _test_group_entities_iterator()
    @testset "GroupEntities" begin
        graph = SpineInterface.empty_entity_group_graph()
        @test collect(SpineInterface.GroupEntities(graph)) == []
        add_entity_group_member!(graph, :group1, :member1)
        add_entity_group_member!(graph, :group1, :member2)
        add_entity_group_member!(graph, :group2, :member2)
        add_entity_group_member!(graph, :group2, :member3)
        @test sort(collect(SpineInterface.GroupEntities(graph))) == sort([:group1, :group2])
    end
end

@testset "graphs" begin
    _test_empty_entity_class_graph()
    _test_add_entity_class()
    _test_add_object_class()
    _test_add_relationship_class()
    _test_add_superclass()
    _test_class_labels()
    _test_classes_in_dependency_order_iterator()
    _test_is_object_class()
    _test_is_relationship_class()
    _test_is_superclass()
    _test_is_subclass_of()
    _test_subclasses()
    _test_dimensionality()
    _test_dimensions_iterator()
    _test_atomic_dimensions()
    _test_resolve_atomic_dimension_choices()
    _test_atomic_dimensionality()
    _test_has_entity()
    _test_subclass_vertex_with_entity()
    _test_entities()
    _test_add_entity()
    _test_add_parameter_definition()
    _test_set_parameter_value()
    _test_concrete_subclass_labels_iterator()
    _test_find_objects()
    _test_find_relationships()
    _test_find_relationships_compact()
    _test_class_for_object()
    _test_delete_future_rophan_dependee_vertices()
    _test_delete_future_rophan_dependant_vertices()
    _test_remove_entity()
    _test_has_relationship()
    _test_add_relationship()
    _test_relationship_atoms_iterator()
    _test_all_atom_tuples()
    _test_atom_passes_selection()
    _test_selected_relationships_iterator()
    _test_add_time_slice_pair()
    _test_add_entity_group_member()
    _test_default_value()
    _test_find_value()
    _test_value_or_default()
    _test_is_group_entity()
    _test_group_entities_iterator()
end
