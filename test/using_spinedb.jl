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
@testset "using_spinedb - basics" begin
    url = "sqlite://"
    @testset "object_class" begin
        object_classes = ["institution"]
        institutions = ["VTT", "KTH", "KUL", "ER", "UCD"]
        objects = [["institution", x] for x in (institutions..., "Spine")]
        object_groups = [["institution", "Spine", x] for x in institutions]
        db_map = db_api.DatabaseMapping(url, create=true)
        db_api.import_data(db_map; object_classes=object_classes, objects=objects, object_groups=object_groups)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        @test length(institution()) === 6
        @test all(x isa Object for x in institution())
        @test [x.name for x in institution()] == vcat(Symbol.(institutions), :Spine)
        @test institution(:FIFA) === nothing
        @test length(object_class()) === 1
        @test all(x isa ObjectClass for x in object_class())
        max_object_id = maximum(obj.id for obj in institution())
        FIFA = Object(:FIFA)
        @test FIFA.id === max_object_id + 1
        Spine = institution(:Spine)
        @test members(Spine) == institution()[1:end-1]
        @test isempty(groups(Spine))
        @testset for i in institution()[1:end-1]
            @test members(i) == [i]
            @test groups(i) == [Spine]
        end
    end
    @testset "relationship_class" begin
        object_classes = ["institution", "country"]
        relationship_classes =
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
        db_map = db_api.DatabaseMapping(url, create=true)
        db_api.import_data(
            db_map;
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            objects=objects,
            relationships=relationships,
        )
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        @test length(institution__country()) === 7
        @test all(x isa RelationshipLike for x in institution__country())
        @test [x.name for x in institution__country(country=country(:France))] == [:KTH, :ER]
        @test [x.name for x in institution__country(institution=institution(:KTH))] == [:Sweden, :France]
        @test [(x.name, y.name) for (x, y) in institution__country(country=country(:France), _compact=false)] == [(:KTH, :France), (:ER, :France)]
        @test [(x.name, y.name) for (x, y) in institution__country()] == [(Symbol(x), Symbol(y)) for (x, y) in institution_country_tuples]
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
        @test length(relationship_class()) === 2
        @test all(x isa RelationshipClass for x in relationship_class())
    end
    @testset "parameter" begin
        object_classes = ["institution", "country"]
        relationship_classes = [["institution__country", ["institution", "country"]]]
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
        db_map = db_api.DatabaseMapping(url, create=true)        
        db_api.import_data(
            db_map;
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            objects=objects,
            relationships=relationships,
            object_parameters=object_parameters,
            relationship_parameters=relationship_parameters,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        @test all(x isa RelationshipLike for x in institution__country())
        @test people_count(institution=institution(:KTH), country=country(:France)) == 1
        @test people_count(institution=institution(:KTH), country=country(:Sweden)) == 3
        @test since_year(institution=institution(:KTH)) == 1827
        @test since_year(institution=institution(:VTT), _strict=false) === nothing
        @test_throws ErrorException people_count(institution=institution(:VTT), country=country(:France))
        @test [x.name for x in institution(since_year=1827.0)] == [:KTH]
        @test length(parameter()) === 2
        @test all(x isa Parameter for x in parameter())
    end
end
@testset "using_spinedb - parameter value types" begin
    url = "sqlite://"
    object_classes = ["country"]
    objects = [["country", "France"]]
    object_parameters = [["country", "apero_time"]]
    db_map = db_api.DatabaseMapping(url, create=true)
    db_api.import_data(db_map; object_classes=object_classes, objects=objects, object_parameters=object_parameters)
    @testset "true" begin
        object_parameter_values = [["country", "France", "apero_time", true]]
        db_api.import_data(db_map; object_parameter_values=object_parameter_values)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        @test apero_time(country=country(:France))
    end
    @testset "false" begin
        object_parameter_values = [["country", "France", "apero_time", false]]
        db_api.import_data(db_map; object_parameter_values=object_parameter_values)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        @test !apero_time(country=country(:France))
    end
    @testset "string" begin
        object_parameter_values = [["country", "France", "apero_time", "now!"]]
        db_api.import_data(db_map; object_parameter_values=object_parameter_values)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        @test apero_time(country=country(:France)) == Symbol("now!")
    end
    @testset "array" begin
        data = [4, 8, 7]
        value = Dict("type" => "array", "data" => PyVector(data))
        object_parameter_values = [["country", "France", "apero_time", value]]
        db_api.import_data(db_map; object_parameter_values=object_parameter_values)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        @test apero_time(country=country(:France)) == data
        @test all(apero_time(country=country(:France), i=i) == v for (i, v) in enumerate(data))
    end
    @testset "date_time" begin
        data = "2000-01-01T00:00:00"
        value = Dict("type" => "date_time", "data" => data)
        object_parameter_values = [["country", "France", "apero_time", value]]
        db_api.import_data(db_map; object_parameter_values=object_parameter_values)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        @test apero_time(country=country(:France)) == DateTime(data)
    end
    @testset "duration" begin
        @testset for (k, (t, data)) in enumerate([(Minute, "m"), (Hour, "h"), (Day, "D"), (Month, "M"), (Year, "Y")])
            value = Dict("type" => "duration", "data" => string(k, data))
            object_parameter_values = [["country", "France", "apero_time", value]]
            db_api.import_data(db_map; object_parameter_values=object_parameter_values)
            db_map.commit_session("No comment")
            using_spinedb(db_map)
            @test apero_time(country=country(:France)) == t(k)
        end
    end
    @testset "time_pattern" begin
        data = Dict("M1-4,M9-10" => 300, "M5-8" => 221.5)
        value = Dict("type" => "time_pattern", "data" => data)
        object_parameter_values = [["country", "France", "apero_time", value]]
        db_api.import_data(db_map; object_parameter_values=object_parameter_values)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        France = country(:France)
        @test apero_time(country=France) isa SpineInterface.TimePattern
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 2))) == 300
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 5), DateTime(0, 8))) == 221.5
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 12))) == (221.5 + 300) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 11), DateTime(0, 12))) === nothing
    end
    @testset "std_time_series" begin
        data = [1.0, 4.0, 5.0, NaN, 7.0]
        index = Dict("start" => "2000-01-01T00:00:00", "resolution" => "1M", "repeat" => false, "ignore_year" => true)
        value = Dict("type" => "time_series", "data" => PyVector(data), "index" => index)
        object_parameter_values = [["country", "France", "apero_time", value]]
        db_api.import_data(db_map; object_parameter_values=object_parameter_values)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        France = country(:France)
        @test apero_time(country=France) isa TimeSeries
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 2))) == 1.0
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 3))) == (1.0 + 4.0) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 2), DateTime(0, 3, 15))) == (4.0 + 5.0) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 3, 2), DateTime(0, 3, 3))) === 5.0
        @test isnan(apero_time(country=France, t=TimeSlice(DateTime(0, 4), DateTime(0, 5))))
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 4), DateTime(0, 5, 2))) == 7.0
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 3), DateTime(0, 5, 2))) == (5.0 + 7.0) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 6), DateTime(0, 7))) === nothing
    end
    @testset "repeating_time_series" begin
        data = [1, 4, 5, 3, 7]
        index = Dict("start" => "2000-01-01T00:00:00", "resolution" => "1M", "repeat" => true, "ignore_year" => true)
        value = Dict("type" => "time_series", "data" => PyVector(data), "index" => index)
        object_parameter_values = [["country", "France", "apero_time", value]]
        db_api.import_data(db_map; object_parameter_values=object_parameter_values)
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        France = country(:France)
        @test apero_time(country=France) isa TimeSeries
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 2))) == data[1]
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 3))) == sum(data[1:2]) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 2), DateTime(0, 3, 15))) == sum(data[2:3]) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 6), DateTime(0, 7))) == sum(data[2:3]) / 2
        @test apero_time(country=France, t=TimeSlice(DateTime(0, 1), DateTime(0, 7))) == sum([data; data[1:3]]) / 8
    end
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
                            "data" => PyVector([4.0, 5.6]),
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
                            "data" => PyVector([2.1, 1.8]),
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
        db_api.import_data(
            db_map;
            object_classes=object_classes,
            objects=objects,
            object_parameter_values=object_parameter_values,
        )
        db_map.commit_session("No comment")
        using_spinedb(db_map)
        France = country(:France)
        drunk = scenario(:drunk)
        sober = scenario(:sober)
        t0 = DateTime(1999, 12)
        t1_2 = TimeSlice(DateTime(2000, 1), DateTime(2000, 2))
        t1_3 = TimeSlice(DateTime(2000, 1), DateTime(2000, 3))
        t2_3 = TimeSlice(DateTime(2000, 2), DateTime(2000, 3))
        @test apero_time(; country=France, s=drunk, t0=t0, t=t2_3) == 5.6
        @test apero_time(; country=France, s=drunk, t0=t0, t=t1_3) == (4.0 + 5.6) / 2
        @test apero_time(; country=France, s=sober, t0=t0, t=t1_2) == 2.1
        @test apero_time(; country=France, s=sober, t0=t0, t=t1_3) == (2.1 + 1.8) / 2
        @test apero_time(; country=France, s=drunk, whatever=:whatever, t0=t0, t=t2_3) == 5.6
        @test apero_time(; country=France, s=drunk, t0=t0, whocares=t0, t=t2_3) == 5.6
    end
end
