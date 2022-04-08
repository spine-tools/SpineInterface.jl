#############################################################################
# Copyright (C) 2017 - 2018  Spine Project
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

# Initialise an in-memory database to avoid `StackOverflowError` when running this file solo???
using_spinedb("sqlite://")

@testset "object_class_to_dict" begin
    objects = [Object(:silvester), Object(:tom)]
    parameter_values = Dict(obj => Dict(:age => parameter_value(k)) for (k, obj) in enumerate(objects))
    parameter_defaults = Dict(:age => parameter_value(9))
    cls = ObjectClass(:cat, objects, parameter_values, parameter_defaults)
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
    silvester = Object(:silvester)
    tom = Object(:tom)
    pluto = Object(:pluto)
    object_tuples = [(silvester, tom, pluto), (tom, silvester, pluto)]
    parameter_values = Dict(x => Dict(:aver_age => parameter_value(k)) for (k, x) in enumerate(object_tuples))
    parameter_defaults = Dict(:aver_age => parameter_value(9))
    cls = RelationshipClass(:cat__cat__dog, [:cat, :cat, :dog], object_tuples, parameter_values, parameter_defaults)
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
        @test Set(v) == Set(d_obs[k])
    end
end


