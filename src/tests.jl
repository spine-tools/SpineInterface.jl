#=
    tests.jl

This file contains functions for ensuring the archetype building definitions are valid.
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
        param::Parameter, object_class::ObjectClass; value_type=nothing, value_min::Real=-Inf, value_max::Real=Inf
    )

Test if `param` value has the expected `DataType` and/or is contained between `value_min`, and `value_max` for each `object`.

A method is provided for also testing `RelationshipClass` parameters.
"""
function test_parameter(
    param::Parameter, object_class::ObjectClass; value_type=nothing, value_min::Real=-Inf, value_max::Real=Inf
)
    @testset """
    Testing parameter `$(param)` for `$(object_class)` for `$(value_type)` within `[$(value_min),$(value_max)]`.
    """ begin
        for object in object_class.objects
            if !isnothing(value_type)
                @test _check(
                    object_class.parameter_values[object][param.name].value isa value_type,
                    "Unexpected type for `$(param)` for `$(object)` in `$(object_class)`! `$(value_type)` expected."
                )
            end
            if value_type isa Real
                @test _check(
                    value_min <= object_class.parameter_values[object][param.name].value <= value_max,
                    "`$(param)` for `$(object)` in `$(object_class)` outside expected range `[$(value_min),$(value_max)]`!"
                )
            end
        end
    end
end
function test_parameter(
    param::Parameter, relationship_class::RelationshipClass; value_type=nothing, value_min::Real=-Inf, value_max::Real=Inf
)
    @testset """
    Testing parameter `$(param)` for `$(relationship_class)` for `$(value_type)` within `[$(value_min),$(value_max)]`.
    """ begin
        for relationship in relationship_class.relationships
            if !isnothing(value_type)
                @test _check(
                    relationship_class.parameter_values[tuple(relationship...)][param.name].value isa value_type,
                    "Unexpected type for `$(param)` for `$(relationship)` in `$(relationship_class)`! `$(value_type)` expected."
                )
            end
            if value_type isa Real
                @test _check(
                    value_min <= relationship_class.parameter_values[tuple(relationship...)][param.name].value <= value_max,
                    "`$(param)` for `$(relationship)` in `$(relationship_class)` outside expected range `[$(value_min),$(value_max)]`!"
                )
            end
        end
    end
end


"""
    test_object_class(object_class::ObjectClass; included_in=nothing, n_entries_min::Real=0, n_entries_max::Real=Inf)

Test if the `object_class` is `included_in` the desired `RelationshipClasses` with a desired number of entries for each `object`.
"""
function test_object_class(object_class::ObjectClass; included_in=nothing, n_entries_min::Real=0, n_entries_max::Real=Inf)
    @testset """
    Testing `$(object_class)` in `$(included_in)` with entry numbers within `[$(n_entries_min),$(n_entries_max)]`.
    """ begin
        if !isnothing(included_in)
            obs_in_rels = getfield.(included_in.relationships, object_class.name)
            @test _check(
                !isempty(obs_in_rels),
                "`$(object_class)` not included in `$(included_in)`!"
            )
            for object in object_class.objects
                @test _check(
                    n_entries_min <= count(entry -> entry == object, obs_in_rels) <= n_entries_max,
                    "Number of `$(object)` relationships in `$(included_in)` not within desired range `[$(n_entries_min),$(n_entries_max)]`!"
                )
            end
        else
            @info "Nothing to test for `$(object_class)`."
            return nothing
        end
    end
end


"""
    test_relationship_class(
        relationship_class:RelationshipClass; included_in=nothing, n_entries_min::Real=0, n_entries_max::Real=Inf
    )

Test if `relationship_class` is `included_in` another `RelationshipClass` with the desired number of entries.
"""
function test_relationship_class(
    relationship_class::RelationshipClass; included_in=nothing, n_entries_min::Real=0, n_entries_max::Real=Inf
)
@testset """
    Testing `$(relationship_class)` in `$(included_in)` with entry numbers within `[$(n_entries_min),$(n_entries_max)]`.
    """ begin
        if !isnothing(included_in)
            rel_in_rels = zip(
                [
                    getfield.(included_in.relationships, field)
                    for field in relationship_class.intact_object_class_names
                ]...
            )
            for rel in values.(relationship_class.relationships)
                @test _check(
                    n_entries_min <= count(entry -> entry==rel, rel_in_rels) <= n_entries_max,
                    "Number of `$(rel)` relationships in `$(included_in)` not within desired range `[$(n_entries_min),$(n_entries_max)]`!"
                )
            end
        else
            @info "Nothing to test for `$(relationship_class)`."
            return nothing
        end
    end
end