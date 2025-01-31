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
db_url = "sqlite://"

function _test_object_class()
    @testset "object_class" begin
        obj_classes = ["institution"]
        institutions = ["VTT", "KTH", "KUL", "ER", "UCD"]
        objects = [["institution", x] for x in (institutions..., "Spine")]
        object_groups = [["institution", "Spine", x] for x in institutions]
        import_test_data(db_url; object_classes=obj_classes, objects=objects, object_groups=object_groups)
        using_spinedb(db_url)
        @test length(institution()) === 6
        @test all(x isa Entity for x in institution())
        @test Set(x.name for x in institution()) == Set(vcat(Symbol.(institutions), :Spine))
        @test institution(:FIFA) === nothing
        @test length(entity_classes()) === 1
        @test all(x isa EntityClass for x in entity_classes())
        Spine = institution(:Spine)
        @test Set(members(Spine)) == Set(x for x in institution() if x != Spine)
        @test isempty(groups(Spine))
        @testset for i in institution()
            i != Spine || continue
            @test members(i) == []
            @test groups(i) == [Spine]
        end
    end
end

function _test_relationship_class()
    @testset "relationship_class" begin
        obj_classes = ["institution", "country"]
        rel_classes =
            [["institution__country", ["institution", "country"]], ["country__neighbour", ["country", "country"]]]
        institutions = ["VTT", "KTH", "KUL", "ER", "UCD"]
        countries = ["Sweden", "France", "Finland", "Ireland", "Belgium"]
        objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
        institution_country_tuples = [
            ["VTT", "Finland"],
            ["KTH", "Sweden"],
            ["KTH", "France"],
            ["KUL", "Belgium"],
            ["UCD", "Ireland"],
            ["ER", "Ireland"],
            ["ER", "France"],
        ]
        country_neighbour_tuples = [["Sweden", "Finland"], ["France", "Belgium"]]
        relationships = vcat(
            [["institution__country", x] for x in institution_country_tuples],
            [["country__neighbour", x] for x in country_neighbour_tuples],
        )
        import_test_data(
            db_url;
            object_classes=obj_classes,
            relationship_classes=rel_classes,
            objects=objects,
            relationships=relationships,
        )
        using_spinedb(db_url)
        @test length(institution__country()) === 7
        @test all(x isa RelationshipLike for x in institution__country())
        @test Set(x.name for x in institution__country(country=country(:France))) == Set([:KTH, :ER])
        @test Set(x.name for x in institution__country(institution=institution(:KTH))) == Set([:Sweden, :France])
        @test Set(
            (x.name, y.name) for (x, y) in institution__country(country=country(:France), _compact=false)
        ) == Set([(:KTH, :France), (:ER, :France)])
        @test Set((x.name, y.name) for (x, y) in institution__country()) == Set(
            (Symbol(x), Symbol(y)) for (x, y) in institution_country_tuples
        )
        @test isempty(institution__country(country=country(:France), institution=institution(:KTH)))
        @test institution__country(
            country=country(:France),
            institution=institution(:VTT),
            _compact=false,
            _default=10,
        ) == 10
        @test length(country__neighbour()) === 2
        @test all(x isa RelationshipLike for x in country__neighbour())
        @test [x.name for x in country__neighbour(country1=country(:France))] == [:Belgium]
        @test [x.name for x in country__neighbour(country2=country(:Finland))] == [:Sweden]
        @test length(entity_classes()) === 4
        @test all(x isa EntityClass for x in entity_classes())
    end
end

function _test_parameter()
    @testset "parameter" begin
        obj_classes = ["institution", "country"]
        rel_classes = [["institution__country", ["institution", "country"]]]
        object_parameters = [["institution", "since_year"]]
        relationship_parameters = [["institution__country", "people_count"]]
        institutions = ["KTH", "VTT"]
        countries = ["Sweden", "France"]
        objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
        relationships = [["institution__country", ["KTH", "Sweden"]], ["institution__country", ["KTH", "France"]]]
        object_parameter_values = [["institution", "KTH", "since_year", 1827]]
        relationship_parameter_values = [
            ["institution__country", ["KTH", "Sweden"], "people_count", 3],
            ["institution__country", ["KTH", "France"], "people_count", 1],
        ]    
        import_test_data(
            db_url;
            object_classes=obj_classes,
            relationship_classes=rel_classes,
            objects=objects,
            relationships=relationships,
            object_parameters=object_parameters,
            relationship_parameters=relationship_parameters,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )
        using_spinedb(db_url)
        @test all(x isa RelationshipLike for x in institution__country())
        @test people_count(institution=institution(:KTH), country=country(:France)) == 1
        @test people_count(institution=institution(:KTH), country=country(:Sweden)) == 3
        @test since_year(institution=institution(:KTH)) === 1827
        @test since_year(institution=institution(:VTT), _strict=false) === nothing
        @test people_count(institution=institution(:VTT), country=country(:France)) === nothing
        @test [x.name for x in institution(since_year=1827)] == [:KTH]
        @test length(parameters()) === 2
        @test all(x isa Parameter for x in parameters())
    end
end

function _test_pv_type_setup()
    object_classes = ["country"]
    objects = [["country", "France"]]
    object_parameters = [["country", "apero_time"]]
    import_test_data(db_url; object_classes=object_classes, objects=objects, object_parameters=object_parameters)
end

function _test_pv_type_true()
    _test_pv_type_setup()
    @testset "true" begin
        object_parameter_values = [["country", "France", "apero_time", true]]
        import_data(db_url; object_parameter_values=object_parameter_values)
        using_spinedb(db_url)
        @test apero_time(country=country(:France))
    end
end

function _test_pv_type_false()
    _test_pv_type_setup()
    @testset "false" begin
        object_parameter_values = [["country", "France", "apero_time", false]]
        import_data(db_url; object_parameter_values=object_parameter_values)
        using_spinedb(db_url)
        @test !apero_time(country=country(:France))
    end
end

function _test_pv_type_string()
    _test_pv_type_setup()
    @testset "string" begin
        object_parameter_values = [["country", "France", "apero_time", "now!"]]
        import_data(db_url; object_parameter_values=object_parameter_values)
        using_spinedb(db_url)
        @test apero_time(country=country(:France)) == Symbol("now!")
    end
end

function _test_pv_type_array()
    _test_pv_type_setup()
    @testset "array" begin
        data = [4, 8, 7]
        value = Dict("type" => "array", "value_type" => "float", "data" => data)
        object_parameter_values = [["country", "France", "apero_time", value]]
        import_data(db_url; object_parameter_values=object_parameter_values)
        using_spinedb(db_url)
        @test apero_time(country=country(:France)) == data
        @test all(apero_time(country=country(:France), i=i) == v for (i, v) in enumerate(data))
    end
end

function _test_pv_type_date_time()
    _test_pv_type_setup()
    @testset "date_time" begin
        data = "2000-01-01T00:00:00"
        value = Dict("type" => "date_time", "data" => data)
        object_parameter_values = [["country", "France", "apero_time", value]]
        import_data(db_url; object_parameter_values=object_parameter_values)
        using_spinedb(db_url)
        @test apero_time(country=country(:France)) == DateTime(data)
    end
end

function _test_pv_type_duration()
    _test_pv_type_setup()
    @testset "duration" begin
        @testset for (k, (t, data)) in enumerate([(Minute, "m"), (Hour, "h"), (Day, "D"), (Month, "M"), (Year, "Y")])
            value = Dict("type" => "duration", "data" => string(k, data))
            object_parameter_values = [["country", "France", "apero_time", value]]
            import_data(db_url; object_parameter_values=object_parameter_values)
            using_spinedb(db_url)
            @test apero_time(country=country(:France)) == t(k)
        end
    end
end

function _test_pv_type_time_pattern()
    _test_pv_type_setup()
    @testset "time_pattern" begin
        data = Dict("M1-4,M9-10" => 300, "M5-8" => 221.5)
        value = Dict("type" => "time_pattern", "data" => data)
        object_parameter_values = [["country", "France", "apero_time", value]]
        import_data(db_url; object_parameter_values=object_parameter_values)
        using_spinedb(db_url)
        France = country(:France)
        @test apero_time(country=France) isa SpineInterface.TimePattern
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 2))) == 300
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 5), DateTime(0, 8))) == 221.5
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 12))) == (221.5 + 300) / 2
        @test isnan(apero_time(country=France, t=TimeSlice(DateTime(0, 11), DateTime(0, 12))))
    end
end

function _test_pv_type_std_time_series()
    _test_pv_type_setup()
    @testset "std_time_series" begin
        data = [1.0, 4.0, 5.0, NaN, 7.0]
        index = Dict("start" => "2000-01-01T00:00:00", "resolution" => "1M", "repeat" => false, "ignore_year" => true)
        value = Dict("type" => "time_series", "data" => data, "index" => index)
        object_parameter_values = [["country", "France", "apero_time", value]]
        import_data(db_url; object_parameter_values=object_parameter_values)
        using_spinedb(db_url)
        France = country(:France)
        @test apero_time(country=France) isa TimeSeries
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 2))) == 1.0
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 3))) == (1.0 + 4.0) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 2), DateTime(0, 3, 15))) == (4.0 + 5.0) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 3, 2), DateTime(0, 3, 3))) === 5.0
        @test isnan(apero_time(country=France, t=TimeSlice(DateTime(0, 4), DateTime(0, 5))))
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 4), DateTime(0, 5, 2))) == 7.0
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 3), DateTime(0, 5, 2))) == (5.0 + 7.0) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 6), DateTime(0, 7))) === 7.0
    end
end

function _test_pv_type_repeating_time_series()
    _test_pv_type_setup()
    @testset "repeating_time_series" begin
        data = [1, 4, 5, 3, 7]
        index = Dict("start" => "2000-01-01T00:00:00", "resolution" => "1M", "repeat" => true, "ignore_year" => true)
        value = Dict("type" => "time_series", "data" => data, "index" => index)
        object_parameter_values = [["country", "France", "apero_time", value]]
        import_data(db_url; object_parameter_values=object_parameter_values)
        using_spinedb(db_url)
        France = country(:France)
        @test apero_time(country=France) isa TimeSeries
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 2))) == data[1]
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 3))) == sum(data[1:2]) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 2), DateTime(0, 3, 15))) == sum(data[2:3]) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 6), DateTime(0, 7))) == sum(data[2:3]) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 7))) == sum([data; data[1:3]]) / 8
    end
end

function _test_pv_type_map()
    _test_pv_type_setup()
    @testset "map" begin
        object_classes = ["scenario"]
        objects = [["scenario", "drunk"], ["scenario", "sober"]]
        value = Dict(
            "type" => "map",
            "index_type" => "str",
            "data" => Dict(
                "drunk" => Dict(
                    "type" => "map",
                    "index_type" => "date_time",
                    "data" => Dict(
                        "1999-12-01T00:00" => Dict(
                            "type" => "time_series",
                            "data" => [4.0, 5.6],
                            "index" => Dict(
                                "start" => "2000-01-01T00:00:00",
                                "resolution" => "1M",
                                "repeat" => false,
                                "ignore_year" => true,
                            ),
                        ),
                    ),
                ),
                "sober" => Dict(
                    "type" => "map",
                    "index_type" => "date_time",
                    "data" => Dict(
                        "1999-12-01T00:00" => Dict(
                            "type" => "time_series",
                            "data" => [2.1, 1.8],
                            "index" => Dict(
                                "start" => "2000-01-01T00:00:00",
                                "resolution" => "1M",
                                "repeat" => false,
                                "ignore_year" => true,
                            ),
                        ),
                    ),
                ),
            ),
        )
        object_parameter_values = [["country", "France", "apero_time", value]]
        import_data(
            db_url;
            object_classes=object_classes,
            objects=objects,
            object_parameter_values=object_parameter_values,
            on_conflict="replace"
        )
        using_spinedb(db_url)
        France = country(:France)
        drunk = scenario(:drunk)
        sober = scenario(:sober)
        t0 = DateTime(1999, 12)
        t1_2 = TimeSlice(DateTime(2000, 1), DateTime(2000, 2))
        t1_3 = TimeSlice(DateTime(2000, 1), DateTime(2000, 3))
        t2_3 = TimeSlice(DateTime(2000, 2), DateTime(2000, 3))
        @test apero_time(; country=France, s=drunk, t0=t0, t=t1_3) == (4.0 + 5.6) / 2
        @test apero_time(; country=France, s=sober, t0=t0, t=t1_2) == 2.1
        @test apero_time(; country=France, s=sober, t0=t0, t=t1_3) == (2.1 + 1.8) / 2
        @test apero_time(; country=France, s=drunk, whatever=:whatever, t0=t0, t=t2_3) == 5.6
        @test apero_time(; country=France, s=drunk, t0=t0, whocares=t0, t=t2_3) == 5.6
        # All permutations
        @test apero_time(; country=France, s=drunk, t0=t0, t=t2_3) == 5.6
        @test apero_time(; country=France, s=drunk, t=t2_3, t0=t0) == 5.6
        @test apero_time(; country=France, t0=t0, s=drunk, t=t2_3) == 5.6
        @test apero_time(; country=France, t0=t0, t=t2_3, s=drunk) == 5.6
        @test apero_time(; country=France, t=t2_3, s=drunk, t0=t0) == 5.6
        @test apero_time(; country=France, t=t2_3, t0=t0, s=drunk) == 5.6
        @test apero_time(; s=drunk, country=France, t0=t0, t=t2_3) == 5.6
        @test apero_time(; s=drunk, country=France, t=t2_3, t0=t0) == 5.6
        @test apero_time(; s=drunk, t0=t0, country=France, t=t2_3) == 5.6
        @test apero_time(; s=drunk, t0=t0, t=t2_3, country=France) == 5.6
        @test apero_time(; s=drunk, t=t2_3, country=France, t0=t0) == 5.6
        @test apero_time(; s=drunk, t=t2_3, t0=t0, country=France) == 5.6
        @test apero_time(; t0=t0, country=France, s=drunk, t=t2_3) == 5.6
        @test apero_time(; t0=t0, country=France, t=t2_3, s=drunk) == 5.6
        @test apero_time(; t0=t0, s=drunk, country=France, t=t2_3) == 5.6
        @test apero_time(; t0=t0, s=drunk, t=t2_3, country=France) == 5.6
        @test apero_time(; t0=t0, t=t2_3, country=France, s=drunk) == 5.6
        @test apero_time(; t0=t0, t=t2_3, s=drunk, country=France) == 5.6
        @test apero_time(; t=t2_3, country=France, s=drunk, t0=t0) == 5.6
        @test apero_time(; t=t2_3, country=France, t0=t0, s=drunk) == 5.6
        @test apero_time(; t=t2_3, s=drunk, country=France, t0=t0) == 5.6
        @test apero_time(; t=t2_3, s=drunk, t0=t0, country=France) == 5.6
        @test apero_time(; t=t2_3, t0=t0, country=France, s=drunk) == 5.6
        @test apero_time(; t=t2_3, t0=t0, s=drunk, country=France) == 5.6
    end
end

function _test_using_spinedb_in_a_loop()
    @testset "using_spinedb_in_a_loop" begin
        fp = "$(@__DIR__)/deleteme.sqlite"
        rm(fp; force=true)
        db_url = "sqlite:///$fp"
        color_by_alt = Dict("alt1" => "orange", "alt2" => "blue", "alt3" => "black")
        import_test_data(
            db_url;
            alternatives=collect(keys(color_by_alt)),
            object_classes=["fish"],
            objects=[("fish", "Nemo")],
            object_parameters=[("fish", "color")],
            object_parameter_values=[("fish", "Nemo", "color", color, alt) for (alt, color) in color_by_alt],
        )
        for (alt, color) in color_by_alt
            M = Module()
            using_spinedb(db_url, M; filters=Dict("alternatives" => [alt]))
            @test M.color(fish=M.fish(:Nemo)) == Symbol(color)
        end
    end
end

function _temp_db_url()
    fp = tempname()
    "sqlite:///$fp"
end

function _test_using_spinedb_extend()
    @testset "using_spinedb_extend" begin
        db_url = _temp_db_url()
        template = Dict(
            :object_classes => [["fish"], ["dog"]],
            :relationship_classes => [["fish__dog", ["fish", "dog"]]],
            :object_parameters => [["fish", "color", "red"]],
        )
        user_data = Dict(
            :object_classes => [["fish"]],
            :objects => [["fish", "nemo"]],
        )
        Extend = Module()
        import_test_data(db_url; template...)
        using_spinedb(db_url, Extend)
        import_test_data(db_url; user_data...)
        using_spinedb(db_url, Extend; extend=true)
        # Test that default values of missing parameters are found in the template
        @test Extend.color(fish=Extend.fish("nemo")) == :red
    end
end

function _test_using_spinedb_with_env()
    @testset "using_spinedb_with_env" begin
        db_url = _temp_db_url()
        base_data = Dict(
            :object_classes => [["fish"], ["dog"]],
            :objects => [["fish", "Nemo"], ["dog", "Scooby"]],
            :relationship_classes => [["fish__dog", ["fish", "dog"]]],
            :relationships => [["fish__dog", ("Nemo", "Scooby")]],
        )
        env_data = Dict(
            :object_classes => [["fish"], ["dog"]],
            :objects => [["fish", "Dory"], ["dog", "Brian"]],
            :relationship_classes => [["fish__dog", ["fish", "dog"]]],
            :relationships => [["fish__dog", ("Dory", "Brian")]],
        )
        import_test_data(db_url; base_data...)
        using_spinedb(db_url)
        env_db_url = _temp_db_url()
        with_env(:env) do
            import_test_data(env_db_url; env_data...)
            using_spinedb(env_db_url)
        end
        with_env(:env) do
            @test fish() == [fish(:Dory)]
            @test fish__dog() == [(fish=fish(:Dory), dog=dog(:Brian))]
        end
        @test fish() == [fish(:Nemo)]
        @test fish__dog() == [(fish=fish(:Nemo), dog=dog(:Scooby))]
    end
end

@testset "using_spinedb - basics" begin
    _test_object_class()
    _test_relationship_class()
    _test_parameter()
end

@testset "using_spinedb - parameter value types" begin
    _test_pv_type_true()
    _test_pv_type_false()
    _test_pv_type_string()
    _test_pv_type_array()
    _test_pv_type_date_time()
    _test_pv_type_duration()
    _test_pv_type_time_pattern()
    _test_pv_type_std_time_series()
    _test_pv_type_repeating_time_series()
    _test_pv_type_map()
end

@testset "using_spinedb - advanced" begin
    _test_using_spinedb_in_a_loop()
    _test_using_spinedb_extend()
    _test_using_spinedb_with_env()
end
