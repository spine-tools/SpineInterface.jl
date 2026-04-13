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

function _relationship_class()
    @testset "RelationshipClass" begin
        @testset "construction with default arguments" begin
            relationship_class = SpineInterface.RelationshipClass(:bond)
            @test relationship_class.name == :bond
            @test isempty(relationship_class.env_dict)
        end
        @testset "construction with single relationship" begin
            object_tuples = [(SpineInterface.Object(:foo, :Widget, [], []), SpineInterface.Object(:bar, :Gadget, [], []))]
            relationship_class = SpineInterface.RelationshipClass(:bond, [:Widget, :Gadget], object_tuples)
            @test relationship_class.name == :bond
            env_dict = relationship_class.env_dict[SpineInterface._active_env()]
            @test env_dict.name == :bond
            @test env_dict.relationships == [(Widget=object_tuples[1][1], Gadget=object_tuples[1][2]),]
        end
    end
end

@testset "type" begin
    _relationship_class()
end
