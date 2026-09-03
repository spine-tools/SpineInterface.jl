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

function _test_parameter_call()
    @testset "calling parameter" begin
        @testset "ambiguous entity order" begin
            @testset "object class parameter returns nothing" begin
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :A)
                add_parameter_definition!(graph, :A, :X)
                add_entity!(graph, :A, :a)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                warning = "can't find a value of X for argument(s) (A = a,)"
                @test_logs (:warn, warning) isnothing(Y.X(; A=Y.A(:a)))
            end
            @testset "2D relationship class" begin
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :A)
                add_entity!(graph, :A, :a)
                add_entity_class!(graph, :B)
                add_entity!(graph, :B, :b)
                add_entity_class!(graph, :A__B, :A, :B)
                add_parameter_definition!(graph, :A__B, :X)
                add_entity!(graph, :A__B, :A => :a, :B => :b)
                set_parameter_value!(graph, :A__B, :X, :A => :a, :B => :b, 2.3)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                warning = "can't find a value of X for arguments (B = b, A = a); check the order of arguments"
                @test_logs (:warn, warning) isnothing(Y.X(; B=Y.B(:b), A=Y.A(:a)))
                @test_logs (:warn, warning) isnothing(Y.X(; B=Y.B(:b), A=Y.A(:a), _strict=false))
            end
            @testset "relationship class of superclasses" begin
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :A)
                add_entity!(graph, :A, :a)
                add_entity_class!(graph, :B)
                add_entity!(graph, :B, :b)
                add_superclass!(graph, :Any, :A, :B)
                add_entity_class!(graph, :Any__Any, :Any, :Any)
                add_parameter_definition!(graph, :Any__Any, :X)
                add_entity!(graph, :Any__Any, :A => :a, :B => :b)
                set_parameter_value!(graph, :Any__Any, :X, :A => :a, :B => :b, 2.3)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                warning = "can't find a value of X for argument(s) (B = b, A = a)"
                @test_logs (:warn, warning) isnothing(Y.X(; B=Y.B(:b), A=Y.A(:a)))
                @test_nowarn isnothing(Y.X(; B=Y.B(:b), A=Y.A(:a), _strict=false))
            end
        end
    end
end

function _test_make_bindings()
    @testset "make_bindings!" begin
        @testset "a little bit of everything" begin
            graph = empty_entity_class_graph()
            add_entity_class!(graph, :A)
            add_parameter_definition!(graph, :A, :X, 3.2)
            add_entity!(graph, :A, :a)
            set_parameter_value!(graph, :A, :X, :a, 2.3)
            add_entity_class!(graph, :B)
            add_entity!(graph, :B, :b)
            add_entity!(graph, :B, :b_group)
            add_entity!(graph, :B, :b_member)
            add_entity_group_member!(graph, :B, :b_group, :b_member)
            add_superclass!(graph, :Any, :A, :B)
            add_entity_class!(graph, :A__B, :A, :B)
            add_entity!(graph, :A__B, :A => :a, :B => :b)
            Y = Bind()
            SpineInterface.make_bindings!(Y, graph)
            @test [o.name for o in Y.A()] == [:a]
            @test Set(o.name for o in Y.B()) == Set([:b, :b_group, :b_member])
            @test members(Y.B(:b_group)) == [Y.B(:b_member)]
            @test members(Y.B(:b_member)) == [Y.B(:b_member)]
            @test groups(Y.B(:b_member)) == [Y.B(:b_group)]
            @test isempty(groups(Y.B(:b_group)))
            @test collect(Y.A__B()) == [(; A = Y.A(:a), B = Y.B(:b))]
            @test sort(collect(Y.Any())) == sort([Y.A(:a), Y.B(:b), Y.B(:b_group), Y.B(:b_member)])
        end
    end
end

@testset "core" begin
    _test_parameter_call()
    _test_make_bindings()
end
