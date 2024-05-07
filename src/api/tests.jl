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

"""
    tests.jl

This file contains functions for testing `Parameter`, `ObjectClass`, and `RelationshipClass` values.
The primary purpose is to make writing database tests easier, e.g. ensuring that all values of a `Parameter` are
of a certain type, or within a specified range for values.
"""

"""
    _check(cond::Bool, msg::String)

Check the condition `cond`, and print `msg` if `false`.
"""
function _check(cond::Bool, msg::String)
    cond || @warn msg
    return cond
end


"""
    test_parameter(
        param::Parameter,
        value_type::Union{DataType,Union,UnionAll},
        m::Module = @__MODULE__;
        value_min::Real = -Inf,
        value_max::Real = Inf,
        limit::Real = Inf,
    )

Test if `param` value in module `m` has the expected `DataType` and is contained between `value_min`, and `value_max`.
The `limit` keyword can be used to limit the number of tests performed.

Methods are provided for testing `ObjectClass` and `RelationshipClass` separately.
"""
function test_parameter(
    param::Parameter,
    value_type::Union{DataType,Union,UnionAll},
    m::Module = @__MODULE__;
    value_min::Real = -Inf,
    value_max::Real = Inf,
    limit::Real = Inf,
)
    @test _check(param in parameters(m), "`$param` not found in module `$m`!")
    for class in param.classes
        test_parameter(param, class, value_type; value_min=value_min, value_max=value_max, limit=limit)
    end
end
function test_parameter(
    param::Parameter,
    obj_class::ObjectClass,
    value_type::Union{DataType,Union,UnionAll};
    value_min::Real=-Inf,
    value_max::Real=Inf,
    limit::Real=Inf,
)
    @testset "Parameter `$param`" begin
        for (i, object) in enumerate(obj_class.objects)
            if i <= limit
                val = _get(obj_class.parameter_values[object], param.name, obj_class.parameter_defaults)()
                cond = val isa value_type
                @test _check(
                    cond,
                    "Unexpected `$param` type `$(typeof(val))` for `$object` - `$value_type` expected!",
                )
                if cond && value_type <: Real
                    @test _check(
                        value_min <= val <= value_max,
                        "`$param` for `$object` value `$val` outside expected range `[$value_min, $value_max]`!",
                    )
                end
            else
                break
            end
        end
    end
end
function test_parameter(
    param::Parameter,
    rel_class::RelationshipClass,
    value_type::Union{DataType,Union,UnionAll};
    value_min::Real=-Inf,
    value_max::Real=Inf,
    limit::Real=Inf,
)
    @testset "Parameter `$param`" begin
        for (i, relationship) in enumerate(rel_class.relationships)
            if i <= limit
                val = _get(
                    rel_class.parameter_values[tuple(relationship...)], param.name, rel_class.parameter_defaults
                )()
                cond = val isa value_type
                @test _check(
                    cond,
                    "Unexpected `$param` type `$(typeof(val))` for `$relationship` - `$value_type` expected!",
                )
                if cond && value_type <: Real
                    @test _check(
                        value_min <= val <= value_max,
                        "`$param` for `$relationship` value `$val` outside expected range `[$value_min, $value_max]`!",
                    )
                end
            else
                break
            end
        end
    end
end


"""
    test_object_class(
        obj_class::ObjectClass,
        rel_class::RelationshipClass,
        m::Module = @__MODULE__;
        count_min::Real = 0,
        count_max::Real = Inf,
        limit::Real = Inf,
    )

Test if the `object_class` in module `m` is included in `relationship_class` with a desired entry count for each `object`.
The `limit` keyword can be used to limit the number of tests performed.
"""
function test_object_class(
    obj_class::ObjectClass,
    rel_class::RelationshipClass,
    m::Module = @__MODULE__;
    count_min::Real=0,
    count_max::Real=Inf,
    limit::Real=Inf,
)
    @test _check(
        obj_class in object_classes(m),
        "`$obj_class` not found in module `$m`!",
    )
    @testset "Object class `$obj_class`" begin
        cond = obj_class.name in rel_class.intact_object_class_names
        @test _check(cond, "`$obj_class` not included in `$rel_class`!")
        if cond
            obs_in_rels = getfield.(rel_class.relationships, obj_class.name)
            for (i, object) in enumerate(obj_class.objects)
                if i <= limit
                    c = count(entry -> entry == object, obs_in_rels)
                    @test _check(
                        count_min <= c <= count_max,
                        "`$object` count `$c` in `$rel_class` not within `[$count_min, $count_max]`!",
                    )
                else
                    break
                end
            end
        end
    end
end


"""
    test_relationship_class(
        rel_class::RelationshipClass,
        in_rel_class::RelationshipClass,
        m::Module = @__MODULE__;
        count_min::Real = 0,
        count_max::Real = Inf,
        limit::Real = Inf,
    )

Test if `relationship_class` in module `m` is included in `in_rel_class` with the desired number of entries.
The `limit` keyword can be used to limit the number of tests performed.
"""
function test_relationship_class(
    rel_class::RelationshipClass,
    in_rel_class::RelationshipClass,
    m::Module = @__MODULE__;
    count_min::Real=0,
    count_max::Real=Inf,
    limit::Real=Inf,
)
    @test _check(rel_class in relationship_classes(m), "`$rel_class` not found in module `$m`!")
    @testset "Relationship class `$(rel_class)`" begin
        fields = intersect(rel_class.object_class_names, in_rel_class.object_class_names)
        cond = !isempty(fields)
        @test _check(cond, "`$rel_class` and `$in_rel_class` have no common `ObjectClasses`!")
        if cond
            rels = zip([getfield.(rel_class.relationships, field) for field in fields]...)
            in_rels =
                zip([getfield.(in_rel_class.relationships, field) for field in fields]...)
            for (i, rel) in enumerate(rels)
                if i <= limit
                    c = count(entry -> entry == rel, in_rels)
                    @test _check(
                        count_min <= c <= count_max,
                        "`$rel` count `$c` in `$in_rel_class` not within `[$count_min, $count_max]`!",
                    )
                else
                    break
                end
            end
        end
    end
end