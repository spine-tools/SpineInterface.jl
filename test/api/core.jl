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
            @testset "non-dimension keywords before the dimensions" begin
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :A)
                add_entity!(graph, :A, :a)
                add_entity!(graph, :A, :a2)
                add_entity_class!(graph, :B)
                add_entity!(graph, :B, :b)
                add_entity_class!(graph, :A__B, :A, :B)
                add_parameter_definition!(graph, :A__B, :X)
                add_entity!(graph, :A__B, :A => :a, :B => :b)
                add_entity!(graph, :A__B, :A => :a2, :B => :b)
                set_parameter_value!(graph, :A__B, :X, :A => :a, :B => :b, 2.3)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                @test Y.X(; analysis_time=1, A=Y.A(:a), B=Y.B(:b)) == 2.3
                warning = "can't find a value of X for argument(s) (analysis_time = 1, A = a2, B = b)"
                @test isnothing(@test_logs (:warn, warning) Y.X(; analysis_time=1, A=Y.A(:a2), B=Y.B(:b)))
                @test isnothing(@test_nowarn Y.X(; analysis_time=1, A=Y.A(:a2), B=Y.B(:b), _strict=false))
                warning = "can't find a value of X for arguments (analysis_time = 1, B = b, A = a2); check the order of arguments"
                @test isnothing(@test_logs (:warn, warning) Y.X(; analysis_time=1, B=Y.B(:b), A=Y.A(:a2), _strict=false))
            end
            @testset "parameter shared by several relationship classes" begin
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :A)
                add_entity!(graph, :A, :a)
                add_entity_class!(graph, :B)
                add_entity!(graph, :B, :b)
                add_entity_class!(graph, :C)
                add_entity!(graph, :C, :c)
                add_entity_class!(graph, :A__B, :A, :B)
                add_entity_class!(graph, :C__B, :C, :B)
                add_parameter_definition!(graph, :A__B, :X)
                add_parameter_definition!(graph, :C__B, :X)
                add_entity!(graph, :A__B, :A => :a, :B => :b)
                add_entity!(graph, :C__B, :C => :c, :B => :b)
                set_parameter_value!(graph, :C__B, :X, :C => :c, :B => :b, 2.3)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                @test Y.X(; analysis_time=1, C=Y.C(:c), B=Y.B(:b)) == 2.3
                @test isnothing(@test_nowarn Y.X(; analysis_time=1, A=Y.A(:a), B=Y.B(:b), _strict=false))
            end
        end
        @testset "no partial match in a class the call doesn't target" begin
            function _graph_with_shared_parameter(; value_on_U__N=false)
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :U)
                add_entity!(graph, :U, :u)
                add_entity!(graph, :U, :u2)
                add_entity_class!(graph, :N)
                add_entity!(graph, :N, :n)
                add_entity!(graph, :N, :n2)
                add_entity_class!(graph, :C)
                add_entity!(graph, :C, :c)
                add_entity_class!(graph, :U__N, :U, :N)
                add_entity_class!(graph, :C__N, :C, :N)
                add_parameter_definition!(graph, :U__N, :X)
                add_parameter_definition!(graph, :C__N, :X)
                add_entity!(graph, :U__N, :U => :u, :N => :n)
                add_entity!(graph, :U__N, :U => :u2, :N => :n2)
                add_entity!(graph, :C__N, :C => :c, :N => :n)
                set_parameter_value!(graph, :C__N, :X, :C => :c, :N => :n, 2.3)
                set_parameter_value!(graph, :U__N, :X, :U => :u2, :N => :n2, 5.0)
                value_on_U__N && set_parameter_value!(graph, :U__N, :X, :U => :u, :N => :n, 9.9)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                Y
            end
            Y = _graph_with_shared_parameter()
            # Misordered call, U__N has no value
            warning = "can't find a value of X for arguments (N = n, U = u); check the order of arguments"
            @test isnothing(@test_logs (:warn, warning) Y.X(; N=Y.N(:n), U=Y.U(:u), _strict=false))
            # Correct order, but the targeted U__N entity (u2, n) doesn't exist
            @test isnothing(@test_nowarn Y.X(; U=Y.U(:u2), N=Y.N(:n), _strict=false))
            # Calls targeting C__N still work
            @test Y.X(; C=Y.C(:c), N=Y.N(:n)) == 2.3
            @test Y.X(; t=1, C=Y.C(:c), N=Y.N(:n)) == 2.3
            # Partial matches without foreign dimensions still work
            @test Y.X(; N=Y.N(:n2)) == 5.0
            @test isnothing(@test_nowarn Y.X(; N=Y.N(:n), _strict=false))  # ambiguous between U__N and C__N
            Y = _graph_with_shared_parameter(; value_on_U__N=true)
            @test Y.X(; U=Y.U(:u), N=Y.N(:n)) == 9.9
            @test isnothing(@test_logs (:warn, warning) Y.X(; N=Y.N(:n), U=Y.U(:u), _strict=false))
            # More keywords than fit in a 64-bit mask
            Y = _graph_with_shared_parameter()
            extra = NamedTuple{Tuple(Symbol(:k, i) for i in 1:70)}(ntuple(_ -> 1, 70))
            @test isnothing(@test_nowarn Y.X(; extra..., U=Y.U(:u2), N=Y.N(:n), _strict=false))
            @test Y.X(; extra..., C=Y.C(:c), N=Y.N(:n)) == 2.3
        end
        @testset "no partial match in a dimension combination the call doesn't target" begin
            # Any__N has the dimension combinations [U, N] and [C, N]
            graph = empty_entity_class_graph()
            add_entity_class!(graph, :U)
            add_entity!(graph, :U, :u)
            add_entity_class!(graph, :N)
            add_entity!(graph, :N, :n)
            add_entity!(graph, :N, :n2)
            add_entity_class!(graph, :C)
            add_entity!(graph, :C, :c)
            add_superclass!(graph, :Any, :U, :C)
            add_entity_class!(graph, :Any__N, :Any, :N)
            add_parameter_definition!(graph, :Any__N, :X)
            add_entity!(graph, :Any__N, :U => :u, :N => :n2)
            add_entity!(graph, :Any__N, :C => :c, :N => :n)
            set_parameter_value!(graph, :Any__N, :X, :U => :u, :N => :n2, 5.0)
            set_parameter_value!(graph, :Any__N, :X, :C => :c, :N => :n, 2.3)
            Y = Bind()
            SpineInterface.make_bindings!(Y, graph)
            # No (u, n) entity: the [C, N] selector must not match (c, n)
            @test isnothing(@test_nowarn Y.X(; U=Y.U(:u), N=Y.N(:n), _strict=false))
            warning = "can't find a value of X for arguments (N = n, U = u); check the order of arguments"
            @test isnothing(@test_logs (:warn, warning) Y.X(; N=Y.N(:n), U=Y.U(:u), _strict=false))
            # Calls targeting each combination, and partial matches, still work
            @test Y.X(; U=Y.U(:u), N=Y.N(:n2)) == 5.0
            @test Y.X(; C=Y.C(:c), N=Y.N(:n)) == 2.3
            @test Y.X(; N=Y.N(:n)) == 2.3
        end
        @testset "parameter without classes" begin
            graph = empty_entity_class_graph()
            add_entity_class!(graph, :A)
            add_entity!(graph, :A, :a)
            Y = Bind()
            SpineInterface.make_bindings!(Y, graph)
            X = Parameter(:X, graph)
            @test isnothing(X(; A=Y.A(:a), _strict=false))
            @test X(; A=Y.A(:a), _default=1.5, _strict=false) == 1.5
        end
        @testset "class and selector method" begin
            @testset "object class parameter" begin
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :A)
                add_parameter_definition!(graph, :A, :X)
                add_entity!(graph, :A, :a)
                set_parameter_value!(graph, :A, :X, :a, 2.3)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                @test Y.X(Y.A, Y.A(:a)) == 2.3
            end
            @testset "missing object class parameter returns default value" begin
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :A)
                add_parameter_definition!(graph, :A, :X, 3.2)
                add_entity!(graph, :A, :a)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                @test Y.X(Y.A, Y.A(:a)) == 3.2
            end
            @testset "_default overwites parameter defaults" begin
                graph = empty_entity_class_graph()
                add_entity_class!(graph, :A)
                add_parameter_definition!(graph, :A, :X, 3.2)
                add_entity!(graph, :A, :a)
                Y = Bind()
                SpineInterface.make_bindings!(Y, graph)
                @test Y.X(Y.A, Y.A(:a); _default=2.3) == 2.3
            end
            @testset "relationship class parameter" begin
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
                @test Y.X(Y.A__B, (Y.A(:a), Y.B(:b))) == 2.3
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
            @test collect(Y.A__B()) == [(; A=Y.A(:a), B=Y.B(:b))]
            @test sort(collect(Y.Any())) == sort([Y.A(:a), Y.B(:b), Y.B(:b_group), Y.B(:b_member)])
        end
    end
end

@testset "core" begin
    _test_parameter_call()
    _test_make_bindings()
end
