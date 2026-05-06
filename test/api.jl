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

db_url = "sqlite://"

function _test_indices()
    @testset "indices" begin
        object_classes = ["institution", "country"]
        relationship_classes = [["institution__country", ["institution", "country"]]]
        object_parameters = [["institution", "since_year", 0]]
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
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            objects=objects,
            relationships=relationships,
            object_parameters=object_parameters,
            relationship_parameters=relationship_parameters,
            object_parameter_values=object_parameter_values,
            relationship_parameter_values=relationship_parameter_values,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        @test Set(indices(Y.people_count)) == Set([
            (institution=Y.institution(:KTH), country=Y.country(:Sweden)),
            (institution=Y.institution(:KTH), country=Y.country(:France)),
        ])
        @test Set(indices(Y.people_count; institution=indices(Y.since_year))) == Set([
            (institution=Y.institution(:KTH), country=Y.country(:Sweden)),
            (institution=Y.institution(:KTH), country=Y.country(:France)),
        ])
        @test only(Y.institution(since_year=1827)) == Y.institution(:KTH)
        @test Y.institution(since_year=0) == [Y.institution(:VTT)] # Tasku: Required by SpineOpt: default values pass parameter value filters.
    end
end

function _test_indices_as_tuples()
    @testset "indices as tuples" begin
        object_classes = ["institution", "country"]
        object_parameters = [["institution", "since_year"]]
        institutions = ["KTH", "ER"]
        objects = [["institution", x] for x in institutions]
        object_parameter_values =
            [["institution", "KTH", "since_year", 1827], ["institution", "ER", "since_year", 2010]]
        import_test_data(
            db_url;
            object_classes=object_classes,
            objects=objects,
            object_parameters=object_parameters,
            object_parameter_values=object_parameter_values,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        @test Set(indices_as_tuples(Y.since_year)) ==
              Set([(institution=Y.institution(:KTH),), (institution=Y.institution(:ER),)])
    end
end

function _test_object_class_relationship_class_parameter()
    @testset "object_class, relationship_class, parameter" begin
        object_classes = ["institution", "country"]
        relationship_classes =
            [["institution__country", ["institution", "country"]], ["country__institution", ["country", "institution"]]]
        object_parameters = [["institution", "since_year"]]
        relationship_parameters = [["institution__country", "people_count"], ["country__institution", "animal_count"]]
        import_test_data(
            db_url;
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            object_parameters=object_parameters,
            relationship_parameters=relationship_parameters,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        @test object_class(:institution, Y) isa ObjectClass
        @test object_class(:institution, Y).name == :institution
        @test object_class(:country, Y) isa ObjectClass
        @test object_class(:country, Y).name == :country
        @test relationship_class(:institution__country, Y) isa RelationshipClass
        @test relationship_class(:institution__country, Y).name == :institution__country
        @test relationship_class(:country__institution, Y) isa RelationshipClass
        @test relationship_class(:country__institution, Y).name == :country__institution
        @test parameter(:people_count, Y) isa Parameter
        @test parameter(:people_count, Y).name == :people_count
        @test parameter(:animal_count, Y) isa Parameter
        @test parameter(:animal_count, Y).name == :animal_count
    end
end

function _test_time_slices()
    @testset "time-slices" begin
        t0_2 = TimeSlice(DateTime(0), DateTime(2); duration_unit=Hour)
        t2_4 = TimeSlice(DateTime(2), DateTime(4); duration_unit=Hour)
        t4_6 = TimeSlice(DateTime(4), DateTime(6); duration_unit=Hour)
        t0_3 = TimeSlice(DateTime(0), DateTime(3); duration_unit=Hour)
        t3_6 = TimeSlice(DateTime(3), DateTime(6); duration_unit=Hour)
        @test duration(t0_2) == Hour(24 * (366 + 365)).value
        @test duration(t0_3) == Hour(24 * (366 + 2 * 365)).value
        @test before(t0_2, t2_4)
        @test !before(t0_2, t3_6)
        @test iscontained(t0_2, t0_3)
        @test iscontained(DateTime(2), t0_3)
        @test !iscontained(t0_2, t2_4)
        @test SpineInterface.contains(t3_6, t4_6)
        @test SpineInterface.contains(t0_3, DateTime(0))
        @test !SpineInterface.contains(t0_3, t4_6)
        @test overlaps(t2_4, t0_3)
        @test !overlaps(t2_4, t4_6)
        @test overlap_duration(t4_6, t3_6) == Hour(24 * (365 + 366)).value
        t = (t0_2, t2_4, t4_6, t0_3, t3_6)
        @test isempty(symdiff(t_lowest_resolution(t), [t2_4, t0_3, t3_6]))
        @test isempty(symdiff(t_highest_resolution(t), [t0_2, t2_4, t4_6]))
        roll!(t0_2, Minute(44))
        @test start(t0_2) == DateTime(0, 1, 1, 0, 44)
        @test end_(t0_2) == DateTime(2, 1, 1, 0, 44)
    end
end

#= Tasku:
The following tests timeslice relationship classes,
which are used quite extensively in SpineOpt.
=#
function _test_timeslice_relationships()
    ts01 = TimeSlice(DateTime(0), DateTime(1))
    ts12 = TimeSlice(DateTime(1), DateTime(2))
    ts23 = TimeSlice(DateTime(2), DateTime(3))
    t_before_t = RelationshipClass(:t_before_t, [:t_before, :t_after], [(ts01, ts12), (ts12, ts23)])
    @test isempty(t_before_t(t_after=ts01))
    @test t_before_t(t_before=ts01) == [ts12]
    @test t_before_t(t_after=ts12) == [ts01]
    @test t_before_t(t_before=ts12) == [ts23]
    @test t_before_t(t_after=ts23) == [ts12]
    @test isempty(t_before_t(t_before=ts23))
end

function _test_add_objects()
    @testset "add_objects" begin
        object_classes = ["institution"]
        institutions = ["VTT", "KTH"]
        objects = [["institution", x] for x in institutions]
        import_test_data(db_url; object_classes=object_classes, objects=objects)
        Y = Bind()
        using_spinedb(db_url, Y)
        @test length(Y.institution()) === 2
        add_objects!(Y.institution, [Y.institution()[1], Object(:KUL), Object(:ER)])
        @test length(Y.institution()) === 4
        @test Set(x.name for x in Y.institution()) == Set([Symbol.(institutions); [:KUL, :ER]])
        add_object!(Y.institution, Object(:UCD))
        @test length(Y.institution()) === 5
        @test last(Y.institution()).name === :UCD
    end
end

function _test_add_relationships()
    @testset "add_relationships" begin
        object_classes = ["institution", "country"]
        relationship_classes =
            [["institution__country", ["institution", "country"]], ["country__country", ["country", "country"]]]
        institutions = ["VTT", "KTH", "KUL", "ER", "UCD"]
        countries = ["Sweden", "France", "Finland", "Ireland", "Belgium"]
        objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
        object_tuples =
            [["VTT", "Finland"], ["KTH", "Sweden"], ["KTH", "France"], ["KUL", "Belgium"], ["UCD", "Ireland"]]
        relationships = [["institution__country", x] for x in object_tuples]
        import_test_data(
            db_url;
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            objects=objects,
            relationships=relationships,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        @test length(Y.institution__country()) === 5
        add_relationships!(
            Y.institution__country,
            [
                Y.institution__country()[3],
                (institution=Object(:ER), country=Object(:France)),
                (institution=Object(:ER), country=Object(:Ireland)),
            ],
        )
        @test length(Y.institution__country()) === 7
        @test Set((x.name, y.name) for (x, y) in Y.institution__country()) == Set([
            [(Symbol(x), Symbol(y)) for (x, y) in object_tuples]
            [(:ER, :France), (:ER, :Ireland)]
        ])
        @test isempty(Y.country__country())
        add_relationships!(Y.country__country, [(country1=Y.country(:Sweden), country2=Y.country(:Sweden))])
        @test Y.country__country() == [(country1=Y.country(:Sweden), country2=Y.country(:Sweden))]
        add_relationships!(
            Y.country__country,
            [
                (country1=Y.country(:Sweden), country2=Y.country(:Sweden)),
                (country1=Y.country(:Finland), country2=Y.country(:Ireland)),
            ],
        )
        @test Y.country__country() == [
            (country1=Y.country(:Sweden), country2=Y.country(:Sweden)),
            (country1=Y.country(:Finland), country2=Y.country(:Ireland)),
        ]
    end
end

function _test_parse_db_value()
    @testset "parse_db_value" begin
        # Add parameter values of all types
        float_value = 18.1 # NOTE! `18.0` gets parsed as an `Int64`!
        int_value = 19
        bool_value = true
        string_value = "asd"
        array_data = [4, 8, 7]
        array_value = Dict("type" => "array", "value_type" => "float", "data" => array_data)
        array_value_with_default_type = Dict("type" => "array", "data" => array_data)
        time_pattern_data = Dict("M1-4,M9-10" => 300, "M5-8" => 221.5)
        time_pattern_value = Dict("type" => "time_pattern", "data" => time_pattern_data)
        time_series_data = [1.0, 4.0, 5.0, -2.0, 7.0]
        time_series_index =
            Dict("start" => "2000-01-01T00:00:00", "resolution" => "1M", "repeat" => false, "ignore_year" => true)
        time_series_value = Dict("type" => "time_series", "data" => time_series_data, "index" => time_series_index)
        map_value = Dict(
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
            ),
        )
        @test parse_db_value(parse_db_value(float_value)) == parse_db_value(float_value)::Float64
        @test parse_db_value(parse_db_value(int_value)) == parse_db_value(int_value)::Int64
        @test parse_db_value(parse_db_value(bool_value)) == parse_db_value(bool_value)::Bool
        @test parse_db_value(parse_db_value(string_value)) == parse_db_value(string_value)::String
        @test parse_db_value(parse_db_value(array_value)) == parse_db_value(array_value)::Array
        @test parse_db_value(parse_db_value(array_value_with_default_type)) ==
              parse_db_value(array_value_with_default_type)::Array
        @test parse_db_value(parse_db_value(time_pattern_value)) == parse_db_value(time_pattern_value)::TimePattern
        @test parse_db_value(parse_db_value(time_series_value)) == parse_db_value(time_series_value)::TimeSeries
        @test parse_db_value(parse_db_value(map_value)) == parse_db_value(map_value)::Map
    end
end

function _test_add_object_parameter_values()
    @testset "add_object_parameter_values" begin
        object_classes = ["institution"]
        institutions = ["ER", "KTH"]
        objects = [["institution", x] for x in institutions]
        object_parameters = [["institution", "since_year"]]
        object_parameter_values =
            [["institution", "KTH", "since_year", 1827], ["institution", "ER", "since_year", 2010]]
        import_test_data(
            db_url;
            object_classes=object_classes,
            objects=objects,
            object_parameters=object_parameters,
            object_parameter_values=object_parameter_values,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        @test length(Y.institution()) === 2
        @test Set(x.name for x in Y.institution()) == Set(Symbol.(institutions))
        ER = Y.institution(:ER)
        @test Y.since_year(institution=ER) == 2010
        pvals = Dict(
            Object(:ER, :institution) => Dict(:since_year => parameter_value(2011)),
            Object(:CORRE_LABS, :institution) =>
                Dict(:since_year => parameter_value(2022), :people_count => parameter_value(3)),
        )
        add_object_parameter_values!(Y.institution, pvals)
        CORRE_LABS = Object(:CORRE_LABS, :institution)
        @test Set(x.name for x in Y.institution()) == Set([Symbol.(institutions); [:CORRE_LABS]])
        @test length(Y.institution()) === 3
        @test Y.since_year(institution=ER) == 2011
        @test Y.since_year(institution=CORRE_LABS) == 2022
    end
end

function _test_add_relationship_parameter_values()
    @testset "add_relationship_parameter_values" begin
        object_classes = ["institution", "country"]
        relationship_classes =
            [["institution__country", ["institution", "country"]], ["country__country", ["country", "country"]]]
        relationship_parameters = [["institution__country", "people_count"], ["country__country", "is_different"]]
        institutions = ["VTT", "KTH", "KUL", "ER", "UCD"]
        countries = ["Sweden", "France", "Finland", "Ireland", "Belgium"]
        objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
        institution_country_tuples =
            [["VTT", "Finland"], ["KTH", "Sweden"], ["KTH", "France"], ["KUL", "Belgium"], ["UCD", "Ireland"]]
        relationships = [["institution__country", [inst, country]] for (inst, country) in institution_country_tuples]
        relationship_parameter_values = [
            ["institution__country", [inst, country], "people_count", k] for
            (k, (inst, country)) in enumerate(institution_country_tuples)
        ]
        import_test_data(
            db_url;
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            relationship_parameters=relationship_parameters,
            objects=objects,
            relationships=relationships,
            relationship_parameter_values=relationship_parameter_values,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        @test length(Y.institution__country()) === 5
        ER = Object(:ER, :institution)
        ERFrance = (institution=ER, country=Y.country(:France))
        ERIreland = (institution=ER, country=Y.country(:Ireland))
        ERSweden = (institution=ER, country=Y.country(:Sweden))
        KTHFrance = (institution=Y.institution(:KTH), country=Y.country(:France))
        pvals = Dict(
            ERFrance => Dict(:people_count => parameter_value(1)),
            ERIreland => Dict(:people_count => parameter_value(1)),
            ERSweden => Dict(:people_count => parameter_value(1)),
            KTHFrance => Dict(:people_count => parameter_value(0)),
        )
        add_relationship_parameter_values!(Y.institution__country, pvals)
        @test length(Y.institution__country()) === 8
        @test Set((x.name, y.name) for (x, y) in Y.institution__country()) == Set(
            [
                [(Symbol(x), Symbol(y)) for (x, y) in institution_country_tuples]
                [(:ER, :France), (:ER, :Ireland), (:ER, :Sweden)]
            ],
        )
        @test Y.people_count(; ERFrance...) == 1
        @test Y.people_count(; ERIreland...) == 1
        @test Y.people_count(; ERSweden...) == 1
        @test Y.people_count(; KTHFrance...) == 0
        pvals = Dict(
            (country1=Y.country(:Sweden), country2=Y.country(:Sweden)) =>
                Dict(:is_different => parameter_value(false)),
            (country1=Y.country(:Sweden), country2=Y.country(:France)) =>
                Dict(:is_different => parameter_value(true)),
        )
        add_relationship_parameter_values!(Y.country__country, pvals)
        @test Y.is_different(country1=Y.country(:Sweden), country2=Y.country(:Sweden)) == false
        @test Y.is_different(country1=Y.country(:Sweden), country2=Y.country(:France)) == true
    end
end

function _test_write_parameters()
    @testset "write_parameters" begin
        path = "$(@__DIR__)/test_out.sqlite"
        url = "sqlite:///$(path)"
        @testset "int & string" begin
            isfile(path) && rm(path)
            parameters = Dict(:apero_time => Dict((country=:France,) => 5, (country=:Sweden, drink=:vodka) => "now!"))
            write_parameters(parameters, url)
            Y = Bind()
            using_spinedb(url, Y)
            @test convert(Int64, Y.apero_time(country=Y.country(:France))) === 5
            @test Y.apero_time(country=Y.country(:Sweden), drink=Y.drink(:vodka)) === Symbol("now!")
        end
        @testset "date_time & duration" begin
            isfile(path) && rm(path)
            parameters =
                Dict(:apero_time => Dict((country=:France,) => DateTime(1), (country=:Sweden, drink=:vodka) => Hour(1)))
            write_parameters(parameters, url)
            Y = Bind()
            using_spinedb(url, Y)
            @test Y.apero_time(country=Y.country(:France)) == DateTime(1)
            @test Y.apero_time(country=Y.country(:Sweden), drink=Y.drink(:vodka)) == Hour(1)
        end
        @testset "array" begin
            isfile(path) && rm(path)
            parameters = Dict(:apero_time => Dict((country=:France,) => [1.0, 2.0, 3.0]))
            write_parameters(parameters, url)
            Y = Bind()
            using_spinedb(url, Y)
            @test Y.apero_time(country=Y.country(:France)) == [1, 2, 3]
        end
        @testset "time_pattern" begin
            isfile(path) && rm(path)
            val =
                Dict(SpineInterface.parse_time_period("D2-5") => 30.5, SpineInterface.parse_time_period("D6-7") => 24.7)
            @test val isa SpineInterface.TimePattern
            parameters = Dict(:apero_time => Dict((country=:France,) => val))
            write_parameters(parameters, url)
            Y = Bind()
            using_spinedb(url, Y)
            @test isnan(Y.apero_time(country=Y.country(:France), t=DateTime(0, 1, 1)))
            @test isnan(Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0, 1, 1), DateTime(0, 1, 1, 23))))
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0, 1, 1), DateTime(0, 1, 5))) == 30.5
            @test Y.apero_time(country=Y.country(:France), t=DateTime(0, 1, 2)) == 30.5
            @test Y.apero_time(country=Y.country(:France), t=DateTime(0, 1, 5)) == 30.5
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0, 1, 5), DateTime(0, 1, 6, 1))) ==
                  (30.5 + 24.7) / 2.0
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0, 1, 6), DateTime(0, 1, 6, 10))) ==
                  24.7
            @test Y.apero_time(country=Y.country(:France), t=DateTime(0, 1, 6)) == 24.7
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0, 1, 7), DateTime(0, 1, 8))) == 24.7
            @test Y.apero_time(country=Y.country(:France), t=DateTime(0, 1, 7)) == 24.7
            @test isnan(Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0, 1, 8), DateTime(0, 1, 31))))
            @test isnan(Y.apero_time(country=Y.country(:France), t=DateTime(0, 1, 8)))
        end
        @testset "time_series" begin
            isfile(path) && rm(path)
            val = TimeSeries([DateTime(1), DateTime(2), DateTime(3)], [4, 5, 6], false, false)
            parameters = Dict(:apero_time => Dict((country=:France,) => val))
            write_parameters(parameters, url)
            Y = Bind()
            using_spinedb(url, Y)
            @test isnan(Y.apero_time(country=Y.country(:France), t=DateTime(0)))
            @test isnan(Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0), DateTime(1))))
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(1), DateTime(2))) == 4
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(1, 2), DateTime(1, 12))) == 4
            @test Y.apero_time(country=Y.country(:France), t=DateTime(1)) == 4
            @test Y.apero_time(country=Y.country(:France), t=DateTime(1, 12)) == 4
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(2), DateTime(3))) == 5
            @test Y.apero_time(country=Y.country(:France), t=DateTime(2)) == 5
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(1), DateTime(3))) == 4.5
            @test Y.apero_time(country=Y.country(:France), t=DateTime(3)) == 6
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(3), DateTime(100))) == 6
            @test isnan(Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(4), DateTime(100))))
            @test isnan(Y.apero_time(country=Y.country(:France), t=DateTime(100)))
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0), DateTime(100))) == 5
        end
        @testset "repeating time_series" begin
            isfile(path) && rm(path)
            # NOTE: Repeating time series should always end with the same value as it started!
            # NOTE: Needs to include a 4-year span to avoid 1-day mismatches caused by leap years.
            val = TimeSeries(
                [DateTime(1), DateTime(2), DateTime(3), DateTime(4), DateTime(5)],
                [4, 5, 6, 7, 4],
                false,
                true,
            )
            parameters = Dict(:apero_time => Dict((country=:France,) => val))
            write_parameters(parameters, url)
            Y = Bind()
            using_spinedb(url, Y)
            @test Y.apero_time(country=Y.country(:France), t=DateTime(0)) == 7
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0), DateTime(1))) == 5.5
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(1), DateTime(2))) == 4
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(1, 2), DateTime(1, 12))) == 4
            @test Y.apero_time(country=Y.country(:France), t=DateTime(1)) == 4
            @test Y.apero_time(country=Y.country(:France), t=DateTime(1, 12)) == 4
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(2), DateTime(3))) == 5
            @test Y.apero_time(country=Y.country(:France), t=DateTime(2)) == 5
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(1), DateTime(3))) == 4.5
            @test Y.apero_time(country=Y.country(:France), t=DateTime(4)) == 7
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(4), DateTime(5))) == 5.5
            @test Y.apero_time(country=Y.country(:France), t=DateTime(5)) == 4
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(5), DateTime(6))) == 4
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(5), DateTime(7))) == 4.5
            @test Y.apero_time(country=Y.country(:France), t=DateTime(100)) == 7
            @test Y.apero_time(country=Y.country(:France), t=TimeSlice(DateTime(0), DateTime(100))) == 5.2
        end
        @testset "with report" begin
            isfile(path) && rm(path)
            parameters = Dict(:apero_time => Dict((country=:France,) => "later..."))
            write_parameters(parameters, url; report="report_x")
            M = Bind()
            using_spinedb(url, M)
            @test M.apero_time(report=M.report(:report_x), country=M.country(:France)) === Symbol("later...") # Tasku: Keyword order needs to match now.
        end
    end
end

function _test_call()
    @testset "Call" begin
        @test realize("hey") == "hey"
        call = Call(5)
        @test realize(call) == 5
        call = Call(+, 3, 4)
        @test realize(call) == 7
        France = Object(:France)
        ts = TimeSeries([DateTime(0), DateTime(1)], [40, 70], false, false)
        country = ObjectClass(:country, [France], Dict(France => Dict(:apero_time => parameter_value(ts))))
        apero_time = Parameter(:apero_time, [country])
        call = apero_time[(; country=France, t=TimeSlice(DateTime(0), DateTime(1)))]
        @test realize(call) == 40
        another_call = Call(*, 3, call)
        @test realize(another_call) == 120
    end
end

function _test_maximum_parameter_value()
    @testset "maximum_parameter_value" begin
        object_classes = ["institution", "country"]
        relationship_classes = [["institution__country", ["institution", "country"]]]
        relationship_parameters = [["institution__country", "people_count"]]
        institutions = ["KTH", "VTT", "ER"]
        countries = ["Sweden", "France", "Finland", "Ireland"]
        objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
        relationships = [
            ["institution__country", ["ER", "France"]],
            ["institution__country", ["ER", "Ireland"]],
            ["institution__country", ["KTH", "Sweden"]],
            ["institution__country", ["KTH", "France"]],
            ["institution__country", ["VTT", "Finland"]],
            ["institution__country", ["VTT", "Ireland"]],
        ]
        # Add parameter values of all types
        scalar_value = 18
        array_data = [4, 8, 7]
        array_value = Dict("type" => "array", "value_type" => "float", "data" => array_data)
        time_pattern_data = Dict("M1-4,M9-10" => 300, "M5-8" => 221.5)
        time_pattern_value = Dict("type" => "time_pattern", "data" => time_pattern_data)
        time_series_data = [1.0, 4.0, 5.0, NaN, 7.0]
        time_series_index =
            Dict("start" => "2000-01-01T00:00:00", "resolution" => "1M", "repeat" => false, "ignore_year" => true)
        time_series_value = Dict("type" => "time_series", "data" => time_series_data, "index" => time_series_index)
        map_value = Dict(
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
            ),
        )
        relationship_parameter_values = [
            ["institution__country", ["ER", "France"], "people_count", scalar_value],
            ["institution__country", ["ER", "Ireland"], "people_count", array_value],
            ["institution__country", ["KTH", "Sweden"], "people_count", time_pattern_value],
            ["institution__country", ["KTH", "France"], "people_count", time_series_value],
            ["institution__country", ["VTT", "Finland"], "people_count", map_value],
            ["institution__country", ["VTT", "Ireland"], "people_count", nothing],
        ]
        import_test_data(
            db_url;
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            objects=objects,
            relationships=relationships,
            relationship_parameters=relationship_parameters,
            relationship_parameter_values=relationship_parameter_values,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        @test maximum_parameter_value(Y.people_count) == 300.0
    end
end

function _test_import_data()
    @testset "import_data" begin
        # Clear in-memory db
        import_test_data(db_url; object_classes=[])
        # Create test data
        sc = 1.0
        str = "test"
        dt = DateTime(1)
        dur = Hour(1)
        ar = [1.0, NaN, 3.0]
        tp = Dict(SpineInterface.parse_time_period("Y1-2") => 1.0)
        ts = TimeSeries([DateTime(1), DateTime(2), DateTime(3)], [1.0, 2.0, 1.0], false, false)
        map = Map([1.0, 2.0], [3.0, 4.0])
        pv_dict = Dict(
            :nothing_parameter => parameter_value(nothing),
            :scalar_parameter => parameter_value(sc),
            :string_parameter => parameter_value(str),
            :date_time_parameter => parameter_value(dt),
            :duration_parameter => parameter_value(dur),
            :array_parameter => parameter_value(ar),
            :timepattern_parameter => parameter_value(tp),
            :timeseries_parameter => parameter_value(ts),
            :map_parameter => parameter_value(map),
        )
        # Create objects and object class for testing
        to1 = Object(:test_object_1)
        to2 = Object(:test_object_2)
        original_oc = ObjectClass(:test_oc, [to1, to2], Dict(to1 => pv_dict), pv_dict)
        original_rc =
            RelationshipClass(:test_rc, [:test_oc, :test_oc], [(to1, to2)], Dict((to1, to2) => pv_dict), pv_dict)
        # Import the newly created `ObjectClass` and `RelationshipClass`
        @test import_data(db_url, original_oc, "Import test object class.") == [21, []]
        @test import_data(db_url, original_rc, "Import test relationship class.") == [20, []]
        @test import_data(db_url, [original_oc, original_rc], "Import both object and relationship class.") == [0, []]
        Y = Bind()
        using_spinedb(db_url, Y)
        @testset for pname in keys(pv_dict)
            pval = pv_dict[pname]
            param = getproperty(Y, pname)
            @test isequal(param(test_oc=Y.test_oc(:test_object_1)), SpineInterface._recursive_inner_value(pval))
        end
    end
end

function _test_difference()
    @testset "difference" begin
        import_test_data(
            db_url;
            object_classes=["institution", "country"],
            relationship_classes=[["institution__country", ["institution", "country"]]],
            object_parameters=[["institution", "since_year"]],
            relationship_parameters=[["institution__country", "people_count"]],
        )
        left = export_data(db_url)
        import_test_data(
            db_url;
            object_classes=["institution", "idea"],
            relationship_classes=[["institution__idea", ["institution", "idea"]]],
            object_parameters=[["institution", "since_year"]],
            relationship_parameters=[["institution__idea", "creator"]],
        )
        right = export_data(db_url)
        left_diff = difference(left, right)
        left_parts = [split(strip(x), "  ") for x in split(left_diff, '\n') if !isempty(x)]
        left_expected = [["entity classes", "country"], ["institution__country"], ["parameters", "people_count"]]
        @test left_parts == left_expected
        right_diff = difference(right, left)
        right_parts = [split(strip(x), "  ") for x in split(right_diff, '\n') if !isempty(x)]
        right_expected = [["entity classes", "idea"], ["institution__idea"], ["parameters", "creator"]]
        @test right_parts == right_expected
    end
end

function _test_indexed_values()
    @testset "indexed_values" begin
        object_classes = ["country"]
        countries = ["Sweden", "France", "Finland", "Ireland", "Netherlands", "Denmark"]
        objects = [["country", x] for x in countries]
        object_parameters = [["country", "people_count"]]
        # Add parameter values of all types
        scalar_value = 18
        array_data = [4, 8, 7]
        array_value = Dict("type" => "array", "value_type" => "float", "data" => array_data)
        time_pattern_data = Dict("M1-4,M9-10" => 300, "M5-8" => 221.5)
        time_pattern_value = Dict("type" => "time_pattern", "data" => time_pattern_data)
        time_series_data = [1.0, 4.0, 5.0, -100.0, 7.0]
        time_series_index =
            Dict("start" => "2000-01-01T00:00:00", "resolution" => "1M", "repeat" => false, "ignore_year" => true)
        time_series_value = Dict("type" => "time_series", "data" => time_series_data, "index" => time_series_index)
        map_value = Dict(
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
            ),
        )
        object_parameter_values = [
            ["country", "France", "people_count", scalar_value],
            ["country", "Ireland", "people_count", array_value],
            ["country", "Sweden", "people_count", time_pattern_value],
            ["country", "Netherlands", "people_count", time_series_value],
            ["country", "Finland", "people_count", map_value],
            ["country", "Denmark", "people_count", nothing],
        ]
        import_test_data(
            db_url;
            object_classes=object_classes,
            objects=objects,
            object_parameters=object_parameters,
            object_parameter_values=object_parameter_values,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        @test indexed_values(Y.people_count(country=Y.country(:France))) == Dict(nothing => 18)
        # @show collect(indexed_values(people_count(country=country(:Sweden))))
        @test indexed_values(Y.people_count(country=Y.country(:Finland))) == Dict(
            (:drunk, (DateTime("1999-12-01T00:00:00"), DateTime("0000-01-01T00:00:00"))) => 4.0,
            (:drunk, (DateTime("1999-12-01T00:00:00"), DateTime("0000-02-01T00:00:00"))) => 5.6,
        )
        @test indexed_values(Y.people_count(country=Y.country(:Ireland))) == Dict(1 => 4.0, 2 => 8.0, 3 => 7.0)
        @test (indexed_values(Y.people_count(country=Y.country(:Netherlands)))) == Dict(
            DateTime("0000-01-01T00:00:00") => 1.0,
            DateTime("0000-02-01T00:00:00") => 4.0,
            DateTime("0000-03-01T00:00:00") => 5.0,
            DateTime("0000-04-01T00:00:00") => -100.0,
            DateTime("0000-05-01T00:00:00") => 7.0,
        )
        @test indexed_values(Y.people_count(country=Y.country(:Denmark))) == Dict(nothing => nothing)
    end
end

function _test_bind()
    @testset "Bind" begin
        bind = Bind()
        @test bind isa Bind
        # Initially no properties defined
        @test !hasproperty(bind, :foo)
        @test !hasproperty(bind, :bar)
        # Setting a property via setproperty!
        bind.foo = 42
        @test hasproperty(bind, :foo)
        @test bind.foo == 42
        # Setting another property of a different type
        bind.bar = "hello"
        @test hasproperty(bind, :bar)
        @test bind.bar == "hello"
        # Accessing an undefined property raises KeyError
        @test_throws KeyError bind.undefined_key
        # Overwriting a property replaces its value
        bind.foo = 99
        @test bind.foo == 99
        # Storing an ObjectClass in a Bind
        oc = ObjectClass(:test_node)
        bind.test_node = oc
        @test hasproperty(bind, :test_node)
        @test bind.test_node isa ObjectClass
        @test bind.test_node.name === :test_node
    end
end

function _test_write_interface()
    @testset "write_interface" begin
        @testset "explicit object_classes / relationship_classes / parameter_definitions" begin
            template = Dict(
                "object_classes" => [["commodity"], ["node"]],
                "relationship_classes" => [["node__commodity", ["node", "commodity"]]],
                "parameter_definitions" => [["node", "demand"], ["node__commodity", "flow"]],
            )
            io = IOBuffer()
            write_interface(io, template)
            output = String(take!(io))
            # Header comment
            @test startswith(output, "# Convenience functors\n")
            # ObjectClass declarations
            @test occursin("const commodity = ObjectClass(:commodity)\n", output)
            @test occursin("const node = ObjectClass(:node)\n", output)
            # RelationshipClass declaration
            @test occursin("const node__commodity = RelationshipClass(:node__commodity)\n", output)
            # Parameter declarations
            @test occursin("const demand = Parameter(:demand)\n", output)
            @test occursin("const flow = Parameter(:flow)\n", output)
            # Exports
            @test occursin("export commodity\n", output)
            @test occursin("export node\n", output)
            @test occursin("export node__commodity\n", output)
            @test occursin("export demand\n", output)
            @test occursin("export flow\n", output)
            # Lookup dict declarations
            @test occursin("const _spine_object_classes = Dict{Symbol,ObjectClass}()\n", output)
            @test occursin("const _spine_relationship_classes = Dict{Symbol,RelationshipClass}()\n", output)
            @test occursin("const _spine_parameters = Dict{Symbol,Parameter}()\n", output)
        end
        @testset "entity_classes / object_parameters / relationship_parameters format" begin
            template = Dict(
                "entity_classes" => [["commodity", []], ["node", []], ["node__commodity", ["node", "commodity"]]],
                "object_parameters" => [["node", "demand"]],
                "relationship_parameters" => [["node__commodity", "flow"]],
            )
            io = IOBuffer()
            write_interface(io, template)
            output = String(take!(io))
            @test occursin("const commodity = ObjectClass(:commodity)\n", output)
            @test occursin("const node = ObjectClass(:node)\n", output)
            @test occursin("const node__commodity = RelationshipClass(:node__commodity)\n", output)
            @test occursin("const demand = Parameter(:demand)\n", output)
            @test occursin("const flow = Parameter(:flow)\n", output)
            @test occursin("export commodity\n", output)
            @test occursin("export node\n", output)
            @test occursin("export node__commodity\n", output)
            @test occursin("export demand\n", output)
            @test occursin("export flow\n", output)
        end
        @testset "empty template produces only lookup dicts" begin
            template = Dict{String,Any}()
            io = IOBuffer()
            write_interface(io, template)
            output = String(take!(io))
            @test occursin("const _spine_object_classes = Dict{Symbol,ObjectClass}()\n", output)
            @test occursin("const _spine_relationship_classes = Dict{Symbol,RelationshipClass}()\n", output)
            @test occursin("const _spine_parameters = Dict{Symbol,Parameter}()\n", output)
            @test !occursin("ObjectClass(:", output)
            @test !occursin("RelationshipClass(:", output)
            @test !occursin("Parameter(:", output)
        end
        @testset "names are sorted alphabetically" begin
            template = Dict(
                "object_classes" => [["zoo"], ["apple"], ["mango"]],
                "relationship_classes" => [["zoo__apple", ["zoo", "apple"]], ["apple__mango", ["apple", "mango"]]],
                "parameter_definitions" => [["zoo", "zzz_param"], ["apple", "aaa_param"]],
            )
            io = IOBuffer()
            write_interface(io, template)
            output = String(take!(io))
            lines = split(output, '\n')
            apple_pos = findfirst(l -> occursin("const apple =", l), lines)
            mango_pos = findfirst(l -> occursin("const mango =", l), lines)
            zoo_pos = findfirst(l -> occursin("const zoo =", l), lines)
            @test apple_pos < mango_pos < zoo_pos
            apple_mango_pos = findfirst(l -> occursin("const apple__mango =", l), lines)
            zoo_apple_pos = findfirst(l -> occursin("const zoo__apple =", l), lines)
            @test apple_mango_pos < zoo_apple_pos
            aaa_pos = findfirst(l -> occursin("const aaa_param =", l), lines)
            zzz_pos = findfirst(l -> occursin("const zzz_param =", l), lines)
            @test aaa_pos < zzz_pos
        end
        @testset "duplicate parameter names across classes are deduplicated" begin
            template = Dict(
                "object_classes" => [["institution"], ["country"]],
                "relationship_classes" => [["institution__country", ["institution", "country"]]],
                "parameter_definitions" =>
                    [["institution", "people_count"], ["institution__country", "people_count"]],
            )
            io = IOBuffer()
            write_interface(io, template)
            output = String(take!(io))
            @test count("const people_count = Parameter(:people_count)", output) == 1
            @test count("export people_count", output) == 1
        end
        @testset "object class only, no relationships or parameters" begin
            template = Dict("object_classes" => [["node"]], "relationship_classes" => [], "parameter_definitions" => [])
            io = IOBuffer()
            write_interface(io, template)
            output = String(take!(io))
            @test occursin("const node = ObjectClass(:node)\n", output)
            @test occursin("export node\n", output)
            @test !occursin("RelationshipClass(:", output)
            @test !occursin("Parameter(:", output)
        end
        @testset "generated code is valid Julia syntax" begin
            template = Dict(
                "object_classes" => [["node"], ["commodity"]],
                "relationship_classes" => [["node__commodity", ["node", "commodity"]]],
                "parameter_definitions" => [["node", "demand"]],
            )
            io = IOBuffer()
            write_interface(io, template)
            output = String(take!(io))
            # The full output should parse as a valid Julia block
            @test Meta.parseall(output) isa Expr
        end
    end
end

function _import_superclass_test_data(db_url::String)
    # Tasku: Note that this uses the v0.8 data structure!
    ent_clss = [
        ["node", []],
        ["unit", []],
        ["unit_flow", []],
        ["node__unit", ["node", "unit"]],
        ["unit__node", ["unit", "node"]],
        ["unit_flow__unit_flow", ["unit_flow", "unit_flow"]]
    ]
    supcls_subclss = [
        ["unit_flow", "node__unit"],
        ["unit_flow", "unit__node"]
    ]
    ents = [
        ["node", "n1"],
        ["node", "n2"],
        ["node", "n3"],
        ["unit", "u1"],
        ["unit", "u2"],
        ["node__unit", ["n1", "u1"]],
        ["node__unit", ["n2", "u2"]],
        ["node__unit", ["n1", "u2"]],
        ["unit__node", ["u1", "n1"]],
        ["unit__node", ["u1", "n3"]],
        ["unit__node", ["u2", "n3"]],
        ["unit_flow__unit_flow", ["n1", "u1", "u1", "n3"]],
        ["unit_flow__unit_flow", ["n1", "u1", "n2", "u2"]],
        ["unit_flow__unit_flow", ["u1", "n3", "u2", "n3"]],
        ["unit_flow__unit_flow", ["u1", "n3", "n1", "u1"]],
    ]
    par_defs = [
        ["node__unit", "flow_capacity", 0.0],
        ["unit__node", "flow_capacity", 1.0],
        ["unit_flow__unit_flow", "ratio", 2.0],
    ]
    par_vals = [
        ["node__unit", ["n1", "u1"], "flow_capacity", 4.0],
        ["unit__node", ["u1", "n1"], "flow_capacity", 4.1],
        ["unit__node", ["u1", "n3"], "flow_capacity", 5.0],
        ["node__unit", ["n2", "u2"], "flow_capacity", 6.0],
        ["unit_flow__unit_flow", ["n1", "u1", "u1", "n3"], "ratio", 7.0],
        ["unit_flow__unit_flow", ["u1", "n3", "n1", "u1"], "ratio", 8.0],
    ]
    return import_test_data(
        db_url;
        entity_classes=ent_clss,
        superclass_subclasses=supcls_subclss,
        entities=ents,
        parameter_definitions=par_defs,
        parameter_values=par_vals
    )
end

function _test_superclasses()
    @testset "superclasses" begin
        # Tasku: Note that this test uses the v0.8 data structure!
        _import_superclass_test_data(db_url)
        Y = Bind()
        using_spinedb(db_url, Y)
        # Tests for `unit_flow` and `flow_capacity`
        @test length(Y.unit_flow()) == 6
        @test Y.unit_flow(unit = Y.unit(:u1)) == [
            Y.node(:n1), Y.node(:n1), Y.node(:n3) # Tasku: TODO: IS THIS THE BEHAVIOUR WE WANT?!?
        ]
        @test collect(Y.unit_flow(unit = Y.unit(:u1); _compact=false)) == [
            (node=Y.node(:n1), unit=Y.unit(:u1)),
            (unit=Y.unit(:u1), node=Y.node(:n1)),
            (unit=Y.unit(:u1), node=Y.node(:n3))
        ]
        @test Y.unit_flow(node = Y.node(:n2)) == [Y.unit(:u2)]
        @test collect(Y.unit_flow(node = Y.node(:n2); _compact=false)) == [
            (node=Y.node(:n2), unit=Y.unit(:u2))
        ]
        @test collect(Y.unit_flow(node = anything, unit = Y.unit(:u1); _compact=false)) == [
            (node=Y.node(:n1), unit=Y.unit(:u1))
        ]
        @test collect(Y.unit_flow(unit = Y.unit(:u1), node = anything; _compact=false)) == [
            (unit=Y.unit(:u1), node=Y.node(:n1))
            (unit=Y.unit(:u1), node=Y.node(:n3))
        ]
        @test Y.flow_capacity(node=Y.node(:n1), unit=Y.unit(:u1)) == 4.0
        @test Y.flow_capacity(unit=Y.unit(:u1), node=Y.node(:n1)) == 4.1
        @test Y.flow_capacity(node=Y.node(:n2), unit=Y.unit(:u2)) == 6.0
        @test Y.flow_capacity(unit=Y.unit(:u1), node=Y.node(:n3)) == 5.0
        @test Y.flow_capacity(node=Y.node(:n1), unit=Y.unit(:u2)) == 0.0
        @test Y.flow_capacity(unit=Y.unit(:u2), node=Y.node(:n3)) == 1.0
        @test Y.flow_capacity(unit=Y.unit(:u1), node=Y.node(:n2)) === nothing
        @test collect(indices(Y.flow_capacity)) == [
            (node=Y.node(:n1), unit=Y.unit(:u1)),
            (node=Y.node(:n1), unit=Y.unit(:u2)),
            (node=Y.node(:n2), unit=Y.unit(:u2)),
            (unit=Y.unit(:u1), node=Y.node(:n1)),
            (unit=Y.unit(:u1), node=Y.node(:n3)),
            (unit=Y.unit(:u2), node=Y.node(:n3)),
        ]
        @test collect(indices(Y.flow_capacity; node=anything, unit=anything)) == [
            (node=Y.node(:n1), unit=Y.unit(:u1)),
            (node=Y.node(:n1), unit=Y.unit(:u2)),
            (node=Y.node(:n2), unit=Y.unit(:u2)),
        ]
        #= Tasku: RelationshipClasses have no parameter value filters.
        @test unit_flow(flow_capacity=0.0) == [(node=node(:n1), unit=unit(:u2))]
        @test unit_flow(flow_capacity=4.0) == [(node=node(:n1), unit=unit(:u1))]
        @test unit_flow(flow_capacity=1.0) == [(unit=unit(:u2), node=node(:n3))]
        =#
        # Tests for `unit_flow__unit_flow` and `ratio`
        @test length(Y.unit_flow__unit_flow()) == 4
        @test Y.unit_flow__unit_flow(unit2=Y.unit(:u1)) == [
            (unit1=Y.unit(:u1), node1=Y.node(:n3), node2=Y.node(:n1)),
            (node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n3)),
        ]
        @test collect(Y.unit_flow__unit_flow(unit2=Y.unit(:u1); _compact=false)) == [
            (unit1=Y.unit(:u1), node1=Y.node(:n3), node2=Y.node(:n1), unit2=Y.unit(:u1)),
            (node1=Y.node(:n1), unit1=Y.unit(:u1), unit2=Y.unit(:u1), node2=Y.node(:n3)),
        ]
        @test collect(Y.unit_flow__unit_flow(unit1=Y.unit(:u1); _compact=false)) == [
            (node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n2), unit2=Y.unit(:u2)),
            (unit1=Y.unit(:u1), node1=Y.node(:n3), node2=Y.node(:n1), unit2=Y.unit(:u1)),
            (node1=Y.node(:n1), unit1=Y.unit(:u1), unit2=Y.unit(:u1), node2=Y.node(:n3)),
            (unit1=Y.unit(:u1), node1=Y.node(:n3), unit2=Y.unit(:u2), node2=Y.node(:n3)),
        ]
        @test collect(Y.unit_flow__unit_flow(node1=anything, unit1=Y.unit(:u1); _compact=false)) == [
            (node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n2), unit2=Y.unit(:u2)),
            (node1=Y.node(:n1), unit1=Y.unit(:u1), unit2=Y.unit(:u1), node2=Y.node(:n3)),
        ]
        @test collect(Y.unit_flow__unit_flow(unit1=Y.unit(:u1), node1=anything; _compact=false)) == [
            (unit1=Y.unit(:u1), node1=Y.node(:n3), node2=Y.node(:n1), unit2=Y.unit(:u1)),
            (unit1=Y.unit(:u1), node1=Y.node(:n3), unit2=Y.unit(:u2), node2=Y.node(:n3)),
        ]
        @test collect(Y.unit_flow__unit_flow(node1=anything, unit1=anything, node2=anything, unit2=anything; _compact=false)) == [
            (node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n2), unit2=Y.unit(:u2))
        ]
        @test collect(Y.unit_flow__unit_flow(node1=anything, unit1=anything, node2=anything; _compact=false)) == [
            (node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n2), unit2=Y.unit(:u2))
            (node1=Y.node(:n1), unit1=Y.unit(:u1), unit2=Y.unit(:u1), node2=Y.node(:n3))
        ]
        @test Y.ratio(node1=Y.node(:n1), unit1=Y.unit(:u1), unit2=Y.unit(:u1), node2=Y.node(:n3)) == 7.0
        @test Y.ratio(unit1=Y.unit(:u1), node1=Y.node(:n3), node2=Y.node(:n1), unit2=Y.unit(:u1)) == 8.0
        @test Y.ratio(unit1=Y.unit(:u1), node1=Y.node(:n1), node2=Y.node(:n1), unit2=Y.unit(:u1)) === nothing
        @test Y.ratio(node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n2), unit2=Y.unit(:u2)) == 2.0
        @test collect(indices(Y.ratio)) == [
            (node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n2), unit2=Y.unit(:u2)),
            (unit1=Y.unit(:u1), node1=Y.node(:n3), node2=Y.node(:n1), unit2=Y.unit(:u1)),
            (node1=Y.node(:n1), unit1=Y.unit(:u1), unit2=Y.unit(:u1), node2=Y.node(:n3)),
            (unit1=Y.unit(:u1), node1=Y.node(:n3), unit2=Y.unit(:u2), node2=Y.node(:n3)),
        ]
        @test collect(indices(Y.ratio; node1=anything, unit1=anything)) == [
            (node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n2), unit2=Y.unit(:u2)),
            (node1=Y.node(:n1), unit1=Y.unit(:u1), unit2=Y.unit(:u1), node2=Y.node(:n3)),
        ]
        #= Tasku: Parameter value filtering for relationship classes is not a thing atm.
        @test unit_flow__unit_flow(ratio=2.0) == [
            (node1=node(:n1), unit1=unit(:u1), node2=node(:n2), unit2=unit(:u2)),
            (unit1=unit(:u1), node1=node(:n3), unit2=unit(:u2), node2=node(:n3)),
        ]
        @test collect(unit_flow__unit_flow(node1=anything, unit1=anything, ratio=2.0, _compact=false)) == [
            (node1=node(:n1), unit1=unit(:u1), node2=node(:n2), unit2=unit(:u2)),
        ]
        @test unit_flow__unit_flow(ratio=7.0) == [
            (node1=node(:n1), unit1=unit(:u1), unit2=unit(:u1), node2=node(:n3))
        ]
        =#
        @test Y.unit_flow__unit_flow__node__unit__node__unit() == [
            (node1=Y.node(:n1), unit1=Y.unit(:u1), node2=Y.node(:n2), unit2=Y.unit(:u2)),
        ]
        @test Y.unit_flow__unit_flow__unit__node__node__unit() == [
            (unit1=Y.unit(:u1), node1=Y.node(:n3), node2=Y.node(:n1), unit2=Y.unit(:u1)),
        ]
        @test Y.unit_flow__unit_flow__node__unit__unit__node() == [
            (node1=Y.node(:n1), unit1=Y.unit(:u1), unit2=Y.unit(:u1), node2=Y.node(:n3)),
        ]
        @test Y.unit_flow__unit_flow__unit__node__unit__node() == [
            (unit1=Y.unit(:u1), node1=Y.node(:n3), unit2=Y.unit(:u2), node2=Y.node(:n3)),
        ]
        # Test superclass database extension (to see if it errors)
        using_spinedb(db_url, Y; extend=true)
    end
end

function _test_writing_superclasses()
    @testset "writing superclasses" begin
        # Tasku: Note that this test uses the v0.8 data structure!
        # Read original data to Y.
        _import_superclass_test_data(db_url)
        orig_data = SpineInterface.parse_db_dict!(export_data(db_url))
        Y = Bind()
        using_spinedb(db_url, Y)
        # Reset database contents
        SpineInterface.close_connection(db_url)
        SpineInterface.open_connection(db_url)
        no_data = export_data(db_url)
        @test length(no_data) == 1 # Test that data is indeed gone, only "alternatives" remain.
        # Read Y back into the fresh db
        import_data(db_url, Y, "testing")
        # Re-read database into X
        new_data = SpineInterface.parse_db_dict!(export_data(db_url))
        X = Bind()
        using_spinedb(db_url, X)
        # Test if original and re-read data are identical in X and Y.
        @test orig_data == new_data
        @test keys(getfield(Y, :d)) == keys(getfield(X, :d))
        for ((yname, yvalue), (xname, xvalue)) in zip(getfield(Y, :d), getfield(X, :d))
            @test yname == xname
            if isa(yvalue, SpineInterface.EntityClass)
                @test yvalue() == xvalue()
            end
        end
        # Test that X and Y are distinct by adding : u3 to Y.
        add_object!(Y.unit, Object(:u3, :unit))
        @test Y.unit() != X.unit()
    end
end

function _test_reorder_dimensions()
    @testset "reorder_dimensions" begin
        object_classes = ["institution", "country"]
        relationship_classes = [
            ["institution__country__country", ["institution", "country", "country"]]
        ]
        relationship_parameters = [
            ["institution__country__country", "mobility"],
        ]
        institutions = ["KTH", "VTT"]
        countries = ["Sweden", "France", "Finland"]
        objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
        relationships = [
            ["institution__country__country", ["KTH", "Sweden", "France"]],
            ["institution__country__country", ["KTH", "France", "Sweden"]],
            ["institution__country__country", ["VTT", "Finland", "Sweden"]]
        ]
        relationship_parameter_values = [
            ["institution__country__country", ["KTH", "Sweden", "France"], "mobility", true],
            ["institution__country__country", ["KTH", "France", "Sweden"], "mobility", false],
            ["institution__country__country", ["VTT", "Finland", "Sweden"], "mobility", true],
        ]
        import_test_data(
            db_url;
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            objects=objects,
            relationships=relationships,
            relationship_parameters=relationship_parameters,
            relationship_parameter_values=relationship_parameter_values,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        # Create some new reordered relationship classes
        original_names = [:institution, :country1, :country2]
        reordered_names = [:country1, :institution, :country2]
        perm = SpineInterface._find_permutation(reordered_names, original_names)
        @test perm == [2, 1, 3]
        @test reordered_names == original_names[perm]
        country__institution__country = reorder_dimensions(
            :country__institution__country,
            Y.institution__country__country,
            reordered_names,
        )
        country__institution__country_ = reorder_dimensions(
            :country__institution__country_,
            Y.institution__country__country,
            perm,
        )
        ntups = [
            (country1=Y.country(:France), institution=Y.institution(:KTH), country2=Y.country(:Sweden)),
            (country1=Y.country(:Sweden), institution=Y.institution(:KTH), country2=Y.country(:France)),
            (country1=Y.country(:Finland), institution=Y.institution(:VTT), country2=Y.country(:Sweden)),
        ]
        @test country__institution__country() == ntups
        @test country__institution__country() == country__institution__country_()
        pvs = [
            country__institution__country.parameter_values[key][:mobility].value
            for key in values.(ntups)
        ]
        @test pvs == [false, true, true]
        @test country__institution__country(country1=Y.country(:France)) == [
            (institution=Y.institution(:KTH), country2=Y.country(:Sweden)),
        ]
        @test country__institution__country(institution=Y.institution(:KTH)) == [
            (country1=Y.country(:France), country2=Y.country(:Sweden)),
            (country1=Y.country(:Sweden), country2=Y.country(:France)),
        ]
        @test country__institution__country(country2=Y.country(:Sweden)) == [
            (country1=Y.country(:France), institution=Y.institution(:KTH)),
            (country1=Y.country(:Finland), institution=Y.institution(:VTT)),
        ]
        # Reorder the new classes to match the original.
        iperm = invperm(perm)
        @test original_names == reordered_names[iperm]
        reorder_dimensions!(country__institution__country, original_names)
        reorder_dimensions!(country__institution__country_, iperm)
        @test country__institution__country() == Y.institution__country__country()
        @test country__institution__country_() == Y.institution__country__country()
        pvs = Y.institution__country__country.parameter_values
        @test country__institution__country.parameter_values == pvs
        @test country__institution__country_.parameter_values == pvs
        @test country__institution__country(country1=Y.country(:Sweden)) == [
            (institution=Y.institution(:KTH), country2=Y.country(:France)),
        ]
        @test country__institution__country(institution=Y.institution(:VTT)) == [
            (country1=Y.country(:Finland), country2=Y.country(:Sweden)),
        ]
        @test country__institution__country(country2=Y.country(:France)) == [
            (institution=Y.institution(:KTH), country1=Y.country(:Sweden)),
        ]
        # Check parameter indices changes after reordering the original
        orig_ntups = collect(indices(Y.mobility))
        reorder_dimensions!(Y.institution__country__country, perm)
        @test collect(indices(Y.mobility)) == ntups
        @test Y.mobility(country1=Y.country(:Sweden), institution=Y.institution(:KTH), country2=Y.country(:France))
        reorder_dimensions!(Y.institution__country__country, iperm)
        @test collect(indices(Y.mobility)) == orig_ntups
        @test !(Y.mobility(institution=Y.institution(:KTH), country1=Y.country(:France), country2=Y.country(:Sweden)))
    end
end

function _test_add_dimension()
    @testset "add_dimension!" begin
        object_classes = ["institution", "country", "city"]
        relationship_classes = [["institution__country", ["institution", "country"]]]
        relationship_parameters = [["institution__country", "people_count"]]
        institutions = ["KTH", "VTT"]
        countries = ["Sweden", "France"]
        cities = ["Stockholm", "Paris"]
        objects = vcat(
            [["institution", x] for x in institutions],
            [["country", x] for x in countries],
            [["city", x] for x in cities],
        )
        relationships = [["institution__country", ["KTH", "Sweden"]], ["institution__country", ["KTH", "France"]]]
        relationship_parameter_values = [
            ["institution__country", ["KTH", "Sweden"], "people_count", 3],
            ["institution__country", ["KTH", "France"], "people_count", 1],
        ]
        import_test_data(
            db_url;
            object_classes=object_classes,
            relationship_classes=relationship_classes,
            objects=objects,
            relationships=relationships,
            relationship_parameters=relationship_parameters,
            relationship_parameter_values=relationship_parameter_values,
        )
        Y = Bind()
        using_spinedb(db_url, Y)
        ic1 = Y.institution__country
        ic2 = deepcopy(ic1)
        ic3 = deepcopy(ic1)
        orig_pvs = deepcopy(ic1.parameter_values)
        # First testing adding one dimension.
        add_dimension!(ic1, Y.city(:Stockholm))
        add_dimension!(ic2, :city, Y.city(:Stockholm))
        @test ic1.object_class_names == [:institution, :country, :city]
        @test ic1.object_class_names == ic1.intact_object_class_names
        @test ic2.object_class_names == ic2.intact_object_class_names
        @test ic1.object_class_names == ic2.object_class_names
        @test ic1.relationships == ic2.relationships
        @test collect(values(ic1.parameter_values)) == collect(values(orig_pvs))
        @test ic1.parameter_values == ic2.parameter_values
        @test ic1(institution=Y.institution(:KTH)) == [
            (country=Y.country(:France), city=Y.city(:Stockholm)),
            (country=Y.country(:Sweden), city=Y.city(:Stockholm)),
        ]
        @test isempty(ic1(institution=Y.institution(:VTT)))
        @test ic1(country=Y.country(:Sweden)) == [(institution=Y.institution(:KTH), city=Y.city(:Stockholm))]
        @test ic1(city=Y.city(:Stockholm)) == [
            (institution=Y.institution(:KTH), country=Y.country(:France)),
            (institution=Y.institution(:KTH), country=Y.country(:Sweden)),
        ]
        @test Y.people_count(institution=Y.institution(:KTH), country=Y.country(:France), city=Y.city(:Stockholm)) == 1
        @test Y.people_count(institution=Y.institution(:KTH), country=Y.country(:Sweden), city=Y.city(:Stockholm)) == 3
        @test collect(indices(Y.people_count)) == [
            (institution=Y.institution(:KTH), country=Y.country(:France), city=Y.city(:Stockholm)),
            (institution=Y.institution(:KTH), country=Y.country(:Sweden), city=Y.city(:Stockholm)),
        ]
        # Test adding a second duplicate dimension to ic1
        add_dimension!(ic1, Y.city(:Paris))
        @test ic1.object_class_names == [:institution, :country, :city1, :city2]
        @test ic1.intact_object_class_names == [:institution, :country, :city, :city]
        @test collect(values(ic1.parameter_values)) == collect(values(ic2.parameter_values))
        @test ic1(institution=Y.institution(:KTH)) == [
            (country=Y.country(:France), city1=Y.city(:Stockholm), city2=Y.city(:Paris)),
            (country=Y.country(:Sweden), city1=Y.city(:Stockholm), city2=Y.city(:Paris)),
        ]
        @test ic1(country=Y.country(:France)) == [
            (institution=Y.institution(:KTH), city1=Y.city(:Stockholm), city2=Y.city(:Paris)),
        ]
        @test isempty(ic1(city=Y.city(:Stockholm)))
        @test ic1(city1=Y.city(:Stockholm)) == [
            (institution=Y.institution(:KTH), country=Y.country(:France), city2=Y.city(:Paris)),
            (institution=Y.institution(:KTH), country=Y.country(:Sweden), city2=Y.city(:Paris)),
        ]
        @test isempty(ic1(city2=Y.city(:Stockholm)))
        @test ic1(city2=Y.city(:Paris)) == [
            (institution=Y.institution(:KTH), country=Y.country(:France), city1=Y.city(:Stockholm)),
            (institution=Y.institution(:KTH), country=Y.country(:Sweden), city1=Y.city(:Stockholm)),
        ]
        @test Y.people_count(
            institution=Y.institution(:KTH),
            country=Y.country(:France),
            city1=Y.city(:Stockholm),
            city2=Y.city(:Paris),
        ) == 1
        @test Y.people_count(
            institution=Y.institution(:KTH),
            country=Y.country(:Sweden),
            city1=Y.city(:Stockholm),
            city2=Y.city(:Paris),
        ) == 3
        @test collect(indices(Y.people_count)) == [
            (institution=Y.institution(:KTH), country=Y.country(:France), city1=Y.city(:Stockholm), city2=Y.city(:Paris)),
            (institution=Y.institution(:KTH), country=Y.country(:Sweden), city1=Y.city(:Stockholm), city2=Y.city(:Paris)),
        ]
        # Test adding two duplicate dimensions at once to ic3 to replicate ic1
        add_dimension!(ic3, [Y.city(:Stockholm), Y.city(:Paris)])
        @test ic3.object_class_names == ic1.object_class_names
        @test ic3.intact_object_class_names == ic1.intact_object_class_names
        @test ic3.parameter_values == ic1.parameter_values
        @test ic3() == ic1()
        @test all(
            ic3(;args...) == ic1(;args...)
            for args in [
                (institution=Y.institution(:KTH),),
                (country=Y.country(:France),),
                (city=Y.city(:Stockholm),),
                (city1=Y.city(:Stockholm),),
                (city2=Y.city(:Stockholm),),
                (city2=Y.city(:Paris),),
            ]
        )
    end
end

function _test_parse_db_dict()
    @testset "parse_db!" begin
        url = "sqlite://"
        data = Dict(
            :entity_classes => [
                ["country", [], nothing, nothing, true],
                ["country__country", ["country", "country"], nothing, nothing, true]
            ],
            :entities => [["country", "Finland", nothing]],
            :parameter_definitions => [ # NOTE! This structure was introduced in Spine-DB-API v0.36.4 or newer!
                ["country", "array", "array", nothing, nothing, nothing],
                ["country", "exists", "boolean", nothing, nothing, nothing],
            ],
            :parameter_values => [
                ["country", "Finland", "array", Dict("type" => "array", "value_type" => "float", "data" => [1.0,2.0]), "Base"],
                ["country", "Finland", "exists", true, "Base"],
            ],
            :parameter_value_lists => [["boolean", true]],
            :alternatives => [["Base", "Base alternative"]],
        )
        import_test_data(url; data...)
        parsed_data = export_data(url)
        parsed_data = SpineInterface.parse_db_dict!(parsed_data)
        for (k, v) in data
            @test get(parsed_data, string(k), nothing) == v
        end
    end
end

@testset "api" begin
    _test_indices()
    _test_indices_as_tuples()
    _test_object_class_relationship_class_parameter()
    _test_time_slices()
    _test_timeslice_relationships()
    _test_add_objects()
    _test_add_relationships()
    _test_parse_db_value()
    _test_add_object_parameter_values()
    _test_add_relationship_parameter_values()
    _test_write_parameters()
    _test_call()
    _test_maximum_parameter_value()
    _test_import_data()
    _test_difference()
    _test_indexed_values()
    _test_bind()
    _test_write_interface()
    _test_superclasses()
    _test_writing_superclasses()
    _test_reorder_dimensions()
    _test_add_dimension()
    _test_parse_db_dict()
end
