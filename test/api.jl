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
@testset "indices" begin
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
    using_spinedb(db_url)
    @test Set(indices(people_count)) == Set([
        (institution=institution(:KTH), country=country(:Sweden)),
        (institution=institution(:KTH), country=country(:France)),
    ])
    @test Set(indices(people_count; institution=indices(since_year))) == Set([
        (institution=institution(:KTH), country=country(:Sweden)),
        (institution=institution(:KTH), country=country(:France)),
    ])
end
@testset "indices as tuples" begin
    object_classes = ["institution", "country"]
    object_parameters = [["institution", "since_year"]]
    institutions = ["KTH", "ER"]
    objects = [["institution", x] for x in institutions]
    object_parameter_values = [["institution", "KTH", "since_year", 1827], ["institution", "ER", "since_year", 2010]]
    import_test_data(
        db_url;
        object_classes=object_classes,
        objects=objects,
        object_parameters=object_parameters,
        object_parameter_values=object_parameter_values,
    )
    using_spinedb(db_url)
    @test Set(indices_as_tuples(since_year)) == Set([
        (institution=institution(:KTH),), (institution=institution(:ER),)
    ])
end
@testset "object_class, relationship_class, parameter" begin
    object_classes = ["institution", "country"]
    relationship_classes = [
        ["institution__country", ["institution", "country"]], ["country__institution", ["country", "institution"]]
    ]
    object_parameters = [["institution", "since_year"]]
    relationship_parameters = [["institution__country", "people_count"], ["country__institution", "animal_count"]]
    import_test_data(
        db_url;
        object_classes=object_classes,
        relationship_classes=relationship_classes,
        object_parameters=object_parameters,
        relationship_parameters=relationship_parameters,
    )
    using_spinedb(db_url)
    @test object_class(:institution) isa ObjectClass
    @test object_class(:institution).name == :institution
    @test object_class(:country) isa ObjectClass
    @test object_class(:country).name == :country
    @test relationship_class(:institution__country) isa RelationshipClass
    @test relationship_class(:institution__country).name == :institution__country
    @test relationship_class(:country__institution) isa RelationshipClass
    @test relationship_class(:country__institution).name == :country__institution
    @test parameter(:people_count) isa Parameter
    @test parameter(:people_count).name == :people_count
    @test parameter(:animal_count) isa Parameter
    @test parameter(:animal_count).name == :animal_count
end
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
@testset "add_entities" begin
    @testset "add_objects" begin
        object_classes = ["institution"]
        institutions = ["VTT", "KTH"]
        objects = [["institution", x] for x in institutions]
        import_test_data(db_url; object_classes=object_classes, objects=objects)
        using_spinedb(db_url)
        @test length(institution()) === 2
        add_objects!(institution, [institution()[1], Object(:KUL), Object(:ER)])
        @test length(institution()) === 4
        @test Set(x.name for x in institution()) == Set([Symbol.(institutions); [:KUL, :ER]])
        add_object!(institution, Object(:UCD))
        @test length(institution()) === 5
        @test last(institution()).name === :UCD
    end
    @testset "add_relationships" begin
        object_classes = ["institution", "country"]
        relationship_classes = [["institution__country", ["institution", "country"]]]
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
        using_spinedb(db_url)
        @test length(institution__country()) === 5
        add_relationships!(
            institution__country,
            [
                institution__country()[3],
                (institution=Object(:ER), country=Object(:France)),
                (institution=Object(:ER), country=Object(:Ireland)),
            ],
        )
        @test length(institution__country()) === 7
        @test Set((x.name, y.name) for (x, y) in institution__country()) == Set([
            [(Symbol(x), Symbol(y)) for (x, y) in object_tuples]
            [(:ER, :France), (:ER, :Ireland)]
        ])
    end
end
@testset "add_parameter_values" begin
    @testset "add_object_parameter_values" begin
        object_classes = ["institution"]
        institutions = ["ER", "KTH"]
        objects = [["institution", x] for x in institutions]
        object_parameters = [["institution", "since_year"]]
        object_parameter_values = [
            ["institution", "KTH", "since_year", 1827], ["institution", "ER", "since_year", 2010]
        ]
        import_test_data(
            db_url;
            object_classes=object_classes,
            objects=objects,
            object_parameters=object_parameters,
            object_parameter_values=object_parameter_values
        )
        using_spinedb(db_url)
        @test length(institution()) === 2
        @test Set(x.name for x in institution()) == Set(Symbol.(institutions))
        ER = institution(:ER)
        @test since_year(institution=ER) == 2010
        pvals = Dict(
            Object(:ER, :institution) => Dict(:since_year => parameter_value(2011)),
            Object(:CORRE_LABS, :institution) => Dict(
                :since_year => parameter_value(2022), :people_count => parameter_value(3)
            ),
        )
        add_object_parameter_values!(institution, pvals)
        CORRE_LABS = Object(:CORRE_LABS, :institution)
        @test Set(x.name for x in institution()) == Set([Symbol.(institutions); [:CORRE_LABS]])
        @test length(institution()) === 3
        @test since_year(institution=ER) == 2011
        @test since_year(institution=CORRE_LABS) == 2022
    end
    @testset "add_relationship_parameter_values" begin
        object_classes = ["institution", "country"]
        relationship_classes = [["institution__country", ["institution", "country"]]]
        relationship_parameters = [["institution__country", "people_count"]]
        institutions = ["VTT", "KTH", "KUL", "ER", "UCD"]
        countries = ["Sweden", "France", "Finland", "Ireland", "Belgium"]
        objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
        institution_country_tuples =[
            ["VTT", "Finland"], ["KTH", "Sweden"], ["KTH", "France"], ["KUL", "Belgium"], ["UCD", "Ireland"]
        ]
        relationships = [
            ["institution__country", [inst, country]] for (inst, country) in institution_country_tuples
        ]
        relationship_parameter_values = [
            ["institution__country", [inst, country], "people_count", k]
            for (k, (inst, country)) in enumerate(institution_country_tuples)
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
        using_spinedb(db_url)
        @test length(institution__country()) === 5
        ER = Object(:ER, :institution)
        ERFrance = (institution=ER, country=country(:France))
        ERIreland = (institution=ER, country=country(:Ireland))
        ERSweden = (institution=ER, country=country(:Sweden))
        KTHFrance = (institution=institution(:KTH), country=country(:France))
        pvals = Dict(
            ERFrance => Dict(:people_count => parameter_value(1)),
            ERIreland => Dict(:people_count => parameter_value(1)),
            ERSweden => Dict(:people_count => parameter_value(1)),
            KTHFrance => Dict(:people_count => parameter_value(0)),
        )
        add_relationship_parameter_values!(institution__country, pvals)
        @test length(institution__country()) === 8
        @test Set((x.name, y.name) for (x, y) in institution__country()) == Set([
            [(Symbol(x), Symbol(y)) for (x, y) in institution_country_tuples]
            [(:ER, :France), (:ER, :Ireland), (:ER, :Sweden)]
        ])
        @test people_count(; ERFrance...) == 1
        @test people_count(; ERIreland...) == 1
        @test people_count(; ERSweden...) == 1
        @test people_count(; KTHFrance...) == 0
    end
end
@testset "write_parameters" begin
    path = "$(@__DIR__)/test_out.sqlite"
    url = "sqlite:///$(path)"
    @testset "int & string" begin
        isfile(path) && rm(path)
        parameters = Dict(:apero_time => Dict((country=:France,) => 5, (country=:Sweden, drink=:vodka) => "now!"))
        write_parameters(parameters, url)
        using_spinedb(url)
        @test convert(Int64, apero_time(country=country(:France))) === 5
        @test apero_time(country=country(:Sweden), drink=drink(:vodka)) === Symbol("now!")
    end
    @testset "date_time & duration" begin
        isfile(path) && rm(path)
        parameters = Dict(
            :apero_time => Dict(
                (country=:France,) => DateTime(1),
                (country=:Sweden, drink=:vodka) => Hour(1),
            ),
        )
        write_parameters(parameters, url)
        using_spinedb(url)
        @test apero_time(country=country(:France)) == DateTime(1)
        @test apero_time(country=country(:Sweden), drink=drink(:vodka)) == Hour(1)
    end
    @testset "array" begin
        isfile(path) && rm(path)
        parameters = Dict(:apero_time => Dict((country=:France,) => [1.0, 2.0, 3.0]))
        write_parameters(parameters, url)
        using_spinedb(url)
        @test apero_time(country=country(:France)) == [1, 2, 3]
    end
    @testset "time_pattern" begin
        isfile(path) && rm(path)
        val = Dict(SpineInterface.parse_time_period("D2-5") => 30.5, SpineInterface.parse_time_period("D6-7") => 24.7)
        @test val isa SpineInterface.TimePattern
        parameters = Dict(:apero_time => Dict((country=:France,) => val))
        write_parameters(parameters, url)
        using_spinedb(url)
        @test isnothing(apero_time(country=country(:France), t=DateTime(0, 1, 1)))
        @test isnothing(apero_time(country=country(:France), t=TimeSlice(DateTime(0, 1, 1), DateTime(0, 1, 1, 23))))
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0, 1, 1), DateTime(0, 1, 5))) == 30.5
        @test apero_time(country=country(:France), t=DateTime(0, 1, 2)) == 30.5
        @test apero_time(country=country(:France), t=DateTime(0, 1, 5)) == 30.5
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0, 1, 5), DateTime(0, 1, 6, 1))) == (30.5 + 24.7) / 2.
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0, 1, 6), DateTime(0, 1, 6, 10))) == 24.7
        @test apero_time(country=country(:France), t=DateTime(0, 1, 6)) == 24.7
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0, 1, 7), DateTime(0, 1, 8))) == 24.7
        @test apero_time(country=country(:France), t=DateTime(0, 1, 7)) == 24.7
        @test isnothing(apero_time(country=country(:France), t=TimeSlice(DateTime(0, 1, 8), DateTime(0, 1, 31))))
        @test isnothing(apero_time(country=country(:France), t=DateTime(0, 1, 8)))
    end
    @testset "time_series" begin
        isfile(path) && rm(path)
        val = TimeSeries([DateTime(1), DateTime(2), DateTime(3)], [4, 5, 6], false, false)
        parameters = Dict(:apero_time => Dict((country=:France,) => val))
        write_parameters(parameters, url)
        using_spinedb(url)
        @test isnothing(apero_time(country=country(:France), t=DateTime(0)))
        @test isnothing(apero_time(country=country(:France), t=TimeSlice(DateTime(0), DateTime(1))))
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(1), DateTime(2))) == 4
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(1,2), DateTime(1,12))) == 4
        @test apero_time(country=country(:France), t=DateTime(1)) == 4
        @test apero_time(country=country(:France), t=DateTime(1,12)) == 4
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(2), DateTime(3))) == 5
        @test apero_time(country=country(:France), t=DateTime(2)) == 5
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(1), DateTime(3))) == 4.5
        @test apero_time(country=country(:France), t=DateTime(3)) == 6
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(3), DateTime(100))) == 6
        @test isnothing(apero_time(country=country(:France), t=TimeSlice(DateTime(4), DateTime(100))))
        @test isnothing(apero_time(country=country(:France), t=DateTime(100)))
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0), DateTime(100))) == 5
    end
    @testset "repeating time_series" begin
        isfile(path) && rm(path)
        # NOTE! Repeating time series should always end with the same value as it started!
        # NOTE! Needs to include a 4-year span to avoid 1-day mismatches caused by leap years.
        val = TimeSeries([DateTime(1), DateTime(2), DateTime(3), DateTime(4), DateTime(5)], [4, 5, 6, 7, 4], false, true)
        parameters = Dict(:apero_time => Dict((country=:France,) => val))
        write_parameters(parameters, url)
        using_spinedb(url)
        @test apero_time(country=country(:France), t=DateTime(0)) == 7
        # NOTE! The repeat-boundary behaves quite counterintuitively, but I don't know how to fix it...
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0), DateTime(1))) == 5.5
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(1), DateTime(2))) == 4
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(1,2), DateTime(1,12))) == 4
        @test apero_time(country=country(:France), t=DateTime(1)) == 4
        @test apero_time(country=country(:France), t=DateTime(1,12)) == 4
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(2), DateTime(3))) == 5
        @test apero_time(country=country(:France), t=DateTime(2)) == 5
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(1), DateTime(3))) == 4.5
        @test apero_time(country=country(:France), t=DateTime(4)) == 7
        # NOTE! The repeat-boundary behaves quite counterintuitively, but I don't know how to fix it...
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(4), DateTime(5))) == 5.5
        @test apero_time(country=country(:France), t=DateTime(5)) == 4
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(5), DateTime(6))) == 4
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(5), DateTime(7))) == 4.5
        @test apero_time(country=country(:France), t=DateTime(100)) == 7
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0), DateTime(100))) == 5.2
    end
    @testset "with report" begin
        isfile(path) && rm(path)
        parameters = Dict(:apero_time => Dict((country=:France,) => "later..."))
        write_parameters(parameters, url; report="report_x")
        using_spinedb(url)
        @test apero_time(country=country(:France), report=report(:report_x)) === Symbol("later...")
    end
end
@testset "Call" begin
    @test realize("hey") == "hey"
    call = Call(5)
    @test realize(call) == 5
    @test !is_varying(call)
    call = Call(+, 3, 4)
    @test realize(call) == 7
    @test !is_varying(call)
    France = Object(:France)
    ts = TimeSeries([DateTime(0), DateTime(1)], [40, 70], false, false)
    country = ObjectClass(:country, [France], Dict(France => Dict(:apero_time => parameter_value(ts))))
    apero_time = Parameter(:apero_time, [country])
    call = apero_time[(; country=France, t=TimeSlice(DateTime(0), DateTime(1)))]
    @test realize(call) == 40
    @test is_varying(call)
    another_call = Call(*, 3, call)
    @test realize(another_call) == 120
    @test is_varying(another_call)
end
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
    time_series_value =
        Dict("type" => "time_series", "data" => time_series_data, "index" => time_series_index)
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
    using_spinedb(db_url)
    @test maximum_parameter_value(people_count) == 300.0
end
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
        :map_parameter => parameter_value(map)
    )
    # Create objects and object class for testing
    to1 = Object(:test_object_1)
    to2 = Object(:test_object_2)
    original_oc = ObjectClass(:test_oc, [to1, to2], Dict(to1 => pv_dict), pv_dict)
    original_rc = RelationshipClass(:test_rc, [:test_oc, :test_oc], [(to1, to2)], Dict((to1, to2) => pv_dict), pv_dict)
    # Import the newly created `ObjectClass` and `RelationshipClass`
    @test import_data(db_url, original_oc, "Import test object class.") == []
    @test import_data(db_url, original_rc, "Import test relationship class.") == []
    @test import_data(db_url, [original_oc, original_rc], "Import both object and relationship class.") == []
    Y = Module()
    using_spinedb(db_url, Y)
    @testset for pname in keys(pv_dict)
        pval = pv_dict[pname]
        param = getproperty(Y, pname)
        @test isequal(param(test_oc=Y.test_oc(:test_object_1)), ((pname == :nothing_parameter) ? nothing : pval.value))
    end
end
@testset "difference" begin
    Left = Module()
    Right = Module()
    import_test_data(
        db_url;
        object_classes=["institution", "country"],
        relationship_classes=[["institution__country", ["institution", "country"]]],
        object_parameters=[["institution", "since_year"]],
        relationship_parameters=[["institution__country", "people_count"]],
    )
    using_spinedb(db_url, Left)
    import_test_data(
        db_url;
        object_classes=["institution", "idea"],
        relationship_classes=[["institution__idea", ["institution", "idea"]]],
        object_parameters=[["institution", "since_year"]],
        relationship_parameters=[["institution__idea", "creator"]],
    )
    using_spinedb(db_url, Right)
    left_diff = difference(Left, Right)
    left_parts = [split(strip(x), "  ") for x in split(left_diff, '\n') if !isempty(x)]
    left_expected = [
        ["object classes", "country"], ["relationship classes", "institution__country"], ["parameters", "people_count"]
    ]
    @test left_parts == left_expected
    right_diff = difference(Right, Left)
    right_parts = [split(strip(x), "  ") for x in split(right_diff, '\n') if !isempty(x)]
    right_expected = [
        ["object classes", "idea"], ["relationship classes", "institution__idea"], ["parameters", "creator"]
    ]
    @test right_parts == right_expected
end

# Clear in-memory DB for safety
import_test_data(db_url; object_classes=[])
