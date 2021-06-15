#=
    tests.jl

This file contains functions for testing `Parameter`, `ObjectClass`, and `RelationshipClass` entities.
The primary purpose is to make writing database tests easier, e.g. ensuring that all values of a `Parameter` are
of a certain type, or withing a specified range for values.
=#

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
        param::Parameter, value_type::DataType; value_min::Real=-Inf, value_max::Real=Inf, limit::Real=Inf
    )

Test if `param` value has the expected `DataType` and is contained between `value_min`, and `value_max`.
The `limit` keyword can be used to limit the number of tests performed.

Methods are provided for testing `ObjectClass` and `RelationshipClass` separately.
"""
function test_parameter(
    param::Parameter, value_type::DataType; value_min::Real=-Inf, value_max::Real=Inf, limit::Real=Inf
)
    for class in param.classes
        test_parameter(param, class, value_type; value_min=value_min, value_max=value_max, limit=limit)
    end
end
function test_parameter(
    param::Parameter, obj_class::ObjectClass, value_type::DataType;
    value_min::Real=-Inf, value_max::Real=Inf, limit::Real=Inf
)
    @testset """
    Testing parameter `$(param)` for `$(obj_class)` for `$(value_type)` within `[$(value_min),$(value_max)]`.
    """ begin
        for (i,object) in enumerate(obj_class.objects)
            if i <= limit
                val = _get(
                    obj_class.parameter_values[object],
                    param.name,
                    obj_class.parameter_defaults
                ).value
                @test _check(
                    val isa value_type,
                    "Unexpected `$(param)` type for `$(object)` - `$(value_type)` expected!"
                )
                if value_type <: Real
                    @test _check(
                        value_min <= val <= value_max,
                        "`$(param)` for `$(object)` outside expected range `[$(value_min),$(value_max)]`!"
                    )
                end
            else break
            end
        end
    end
end
function test_parameter(
    param::Parameter, rel_class::RelationshipClass, value_type::DataType;
    value_min::Real=-Inf, value_max::Real=Inf, limit::Real=Inf
)
    @testset """
    Testing parameter `$(param)` for `$(rel_class)` for `$(value_type)` within `[$(value_min),$(value_max)]`.
    """ begin
        for (i,relationship) in enumerate(rel_class.relationships)
            if i <= limit
                val = _get(
                    rel_class.parameter_values[tuple(relationship...)],
                    param.name,
                    rel_class.parameter_defaults
                ).value
                @test _check(
                    val isa value_type,
                    "Unexpected `$(param)` type for `$(relationship)` - `$(value_type)` expected!"
                )
                if value_type <: Real
                    @test _check(
                        value_min <= val <= value_max,
                        "`$(param)` for `$(relationship)` outside expected range `[$(value_min),$(value_max)]`!"
                    )
                end
            else break
            end
        end
    end
end


"""
    test_object_class(
        obj_class::ObjectClass, rel_class::RelationshipClass;
        count_min::Real=0, count_max::Real=Inf, limit::Real=Inf
    )

Test if the `object_class` is included in `relationship_class` with a desired entry count for each `object`.
The `limit` keyword can be used to limit the number of tests performed.
"""
function test_object_class(
    obj_class::ObjectClass, rel_class::RelationshipClass;
    count_min::Real=0, count_max::Real=Inf, limit::Real=Inf
)
    @testset """
    Testing `$(obj_class)` in `$(rel_class)` and entry count within `[$(count_min),$(count_max)]`.
    """ begin
        obs_in_rels = getfield.(rel_class.relationships, obj_class.name)
        isempty(obs_in_rels) && error("`$(obj_class)` not included in `$(rel_class)`!")
        for (i,object) in enumerate(obj_class.objects)
            if i <= limit
                @test _check(
                    count_min <= count(entry -> entry == object, obs_in_rels) <= count_max,
                    "`$(object)` count in `$(rel_class)` not within `[$(count_min),$(count_max)]`!"
                )
            else break
            end
        end
    end
end


"""
    test_relationship_class(
        rel_class:RelationshipClass, in_rel_class::RelationshipClass;
        count_min::Real=0, count_max::Real=Inf, limit::Real=Inf
    )

Test if `relationship_class` is included in `in_rel_class` with the desired number of entries.
The `limit` keyword can be used to limit the number of tests performed.
"""
function test_relationship_class(
    rel_class::RelationshipClass, in_rel_class::RelationshipClass;
    count_min::Real=0, count_max::Real=Inf, limit::Real=Inf
)
@testset """
    Testing `$(rel_class)` in `$(in_rel_class)` entry count within `[$(count_min),$(count_max)]`.
    """ begin
        fields = intersect(rel_class.object_class_names, in_rel_class.object_class_names)
        isempty(fields) && error("`$(rel_class)` and `$(in_rel_class)` have no common `ObjectClasses`!")
        rels = zip([getfield.(rel_class.relationships, field) for field in fields]...)
        in_rels = zip([getfield.(in_rel_class.relationships, field) for field in fields]...)
        for (i,rel) in enumerate(rels)
            if i <= limit
                @test _check(
                    count_min <= count(entry -> entry==rel, in_rels) <= count_max,
                    "`$(rel)` count in `$(in_rel_class)` not within `[$(count_min),$(count_max)]`!"
                )
            else break
            end
        end
    end
end