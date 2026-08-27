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

@testset "object_class_to_dict" begin
    graph = empty_entity_class_graph()
    add_object_class!(graph, :cat)

    add_entity!(graph, :cat, :silvester)
    add_entity!(graph, :cat, :tom)
    add_parameter_definition!(graph, :cat, :age, parameter_value(9))
    set_parameter_value!(graph, :cat, :age, :silvester, parameter_value(1))
    set_parameter_value!(graph, :cat, :age, :tom, parameter_value(2))
    cls = ObjectClass(:cat, graph)
    d_obs = SpineInterface._to_dict(cls)
    d_exp = Dict(
        :object_classes => [:cat],
        :object_parameters => [[:cat, :age, unparse_db_value(9)]],
        :objects => [[:cat, :silvester], [:cat, :tom]],
        :object_parameter_values => [
            [:cat, :tom, :age, unparse_db_value(2)], [:cat, :silvester, :age, unparse_db_value(1)]
        ]
    )
    @test keys(d_obs) == keys(d_exp)
    for (k, v) in d_exp
        @test Set(v) == Set(d_obs[k])
    end
end
@testset "relationship_class_to_dict" begin
    graph = empty_entity_class_graph()
    add_object_class!(graph, :cat)
    add_object_class!(graph, :dog)
    add_entity!(graph, :cat, :silvester)
    add_entity!(graph, :cat, :tom)
    add_entity!(graph, :cat, :pluto)
    cat = ObjectClass(:cat, graph)
    dog = ObjectClass(:dog, graph)
    add_relationship_class!(graph, :cat__cat__dog, :cat, :cat, :dog)
    add_entity!(graph, :cat__cat__dog, :cat => :silvester, :cat => :tom, :dog => :pluto)
    add_entity!(graph, :cat__cat__dog, :cat => :tom, :cat => :silvester, :dog => :pluto)
    add_parameter_definition!(graph, :cat__cat__dog, :aver_age, parameter_value(9))
    set_parameter_value!(graph, :cat__cat__dog, :aver_age, :cat => :silvester, :cat => :tom, :dog => :pluto, parameter_value(1))
    set_parameter_value!(graph, :cat__cat__dog, :aver_age, :cat => :tom, :cat => :silvester, :dog => :pluto, parameter_value(2))
    silvester = Object(:silvester)
    cls = RelationshipClass(:cat__cat__dog, graph, Dict([:cat => cat, :dog => dog]))
    d_obs = SpineInterface._to_dict(cls)
    d_exp = Dict(
        :object_classes => [:cat, :dog],
        :objects => [[:cat, :silvester], [:cat, :tom], [:dog, :pluto]],
        :relationship_classes => [[:cat__cat__dog, [:cat, :cat, :dog]]],
        :relationships => [[:cat__cat__dog, [:silvester, :tom, :pluto]], [:cat__cat__dog, [:tom, :silvester, :pluto]]],
        :relationship_parameters => [[:cat__cat__dog, :aver_age, unparse_db_value(9)]],
        :relationship_parameter_values => [
            [:cat__cat__dog, [:silvester, :tom, :pluto], :aver_age, unparse_db_value(1)],
            [:cat__cat__dog, [:tom, :silvester, :pluto], :aver_age, unparse_db_value(2)]
        ]
    )
    @test keys(d_obs) == keys(d_exp)
    for (k, v) in d_exp
        @test sort(v) == sort(d_obs[k])
    end
end
