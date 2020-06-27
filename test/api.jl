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

@testset "indices" begin
    url = "sqlite:///$(@__DIR__)/test.sqlite"
    object_classes = ["institution", "country"]
    relationship_classes = [["institution__country", ["institution", "country"]]]
    object_parameters = [["institution", "since_year"]]
    relationship_parameters = [["institution__country", "people_count"]]
    institutions = ["KTH", "VTT"]
    countries = ["Sweden", "France"]
    objects = vcat([["institution", x] for x in institutions], [["country", x] for x in countries])
    relationships = [
        ["institution__country", ["KTH", "Sweden"]],
        ["institution__country", ["KTH", "France"]],
    ]
    object_parameter_values = [["institution", "KTH", "since_year", 1827]]
    relationship_parameter_values = [
        ["institution__country", ["KTH", "Sweden"], "people_count", 3],
        ["institution__country", ["KTH", "France"], "people_count", 1],
    ]
    db_api.create_new_spine_database(url)
    db_api.import_data_to_url(
        url; 
        object_classes=object_classes, 
        relationship_classes=relationship_classes, 
        objects=objects, 
        relationships=relationships,
        object_parameters=object_parameters,
        relationship_parameters=relationship_parameters,
        object_parameter_values=object_parameter_values,
        relationship_parameter_values=relationship_parameter_values,
       )
    using_spinedb(url)
    @test collect(indices(people_count)) == [
        (institution=institution(:KTH), country=country(:Sweden)), (institution=institution(:KTH), country=country(:France))
    ]
    @test collect(indices(people_count; institution=indices(since_year))) == [
        (institution=institution(:KTH), country=country(:Sweden)), (institution=institution(:KTH), country=country(:France))
    ]
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
    @test !iscontained(nothing, t3_6)
    @test contains(t3_6, t4_6)
    @test contains(t0_3, DateTime(0))
    @test !contains(t0_3, t4_6)
    @test !contains(nothing, t0_2)
    @test overlaps(t2_4, t0_3)
    @test !overlaps(t2_4, t4_6)
    @test overlap_duration(t4_6, t3_6) == Hour(24 * (365 + 366)).value
    t = (t0_2, t2_4, t4_6, t0_3, t3_6)
    @test isempty(symdiff(t_lowest_resolution(t), [t2_4, t0_3, t3_6]))
    @test isempty(symdiff(t_highest_resolution(t), [t0_2, t2_4, t4_6]))
    roll!(t0_2, Minute(44))
    @test start(t0_2) == DateTime(0, 1, 1, 0, 44)
    @test end_(t0_2) == DateTime(2, 1, 1, 0, 44)
    t_map = TimeSliceMap([t0_2, t2_4, t4_6])
    @test t_map(t0_3) == [t0_2, t2_4]
    @test t_map(t3_6) == [t2_4, t4_6]
end
@testset "add_entities" begin
    url = "sqlite:///$(@__DIR__)/test.sqlite"
    @testset "add_objects" begin
        object_classes = ["institution"]
        institutions = ["VTT", "KTH"]
        objects = [["institution", x] for x in institutions]
        db_api.create_new_spine_database(url)
        db_api.import_data_to_url(url; object_classes=object_classes, objects=objects)
        using_spinedb(url)
        @test length(institution()) === 2
        add_objects!(institution, [institution()[1], Object(:KUL), Object(:ER)])
        @test length(institution()) === 4
        @test [x.name for x in institution()] == [Symbol.(institutions); [:KUL, :ER]]
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
        object_tuples = [
            ["VTT", "Finland"],
            ["KTH", "Sweden"],
            ["KTH", "France"],
            ["KUL", "Belgium"],
            ["UCD", "Ireland"]
        ]
        relationships = [["institution__country", x] for x in object_tuples]
        db_api.create_new_spine_database(url)
        db_api.import_data_to_url(
            url; 
            object_classes=object_classes, 
            relationship_classes=relationship_classes, 
            objects=objects, 
            relationships=relationships
           )
        using_spinedb(url)
        @test length(institution__country()) === 5
        add_relationships!(
            institution__country, 
            [
                institution__country()[3], 
                (institution=Object(:ER), country=Object(:France)), 
                (institution=Object(:ER), country=Object(:Ireland))
            ]
        )
        @test length(institution__country()) === 7
        @test [(x.name, y.name) for (x, y) in institution__country()] == [
            [(Symbol(x), Symbol(y)) for (x, y) in object_tuples]; [(:ER, :France), (:ER, :Ireland)]
        ]
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
                (country=:France,) => SpineInterface.DateTime_(DateTime(1)), 
                (country=:Sweden, drink=:vodka) => SpineInterface.Duration(Hour(1))
            )
        )
        write_parameters(parameters, url)
        using_spinedb(url)
        @test apero_time(country=country(:France)) == DateTime(1)
        @test apero_time(country=country(:Sweden), drink=drink(:vodka)) == Hour(1)
    end
    @testset "array" begin
        isfile(path) && rm(path)
        parameters = Dict(:apero_time => Dict((country=:France,) => SpineInterface.Array_([1.0, 2.0, 3.0])))
        write_parameters(parameters, url)
        using_spinedb(url)
        @test apero_time(country=country(:France)) == [1, 2, 3]
    end
    @testset "time_pattern" begin
        isfile(path) && rm(path)
        val = Dict(SpineInterface.PeriodCollection("D1-5") => 30.5, SpineInterface.PeriodCollection("D6-7") => 24.7)
        @test val isa SpineInterface.TimePattern
        parameters = Dict(:apero_time => Dict((country=:France,) => val))
        write_parameters(parameters, url)
        using_spinedb(url)
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0, 1, 3), DateTime(0, 1, 5))) == 30.5
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(0, 1, 6), DateTime(0, 1, 6, 10))) == 24.7
    end
    @testset "time_series" begin
        isfile(path) && rm(path)
        val = TimeSeries([DateTime(1), DateTime(2), DateTime(3)], [4, 5, 6], false, false)
        parameters = Dict(:apero_time => Dict((country=:France,) => val))
        write_parameters(parameters, url)
        using_spinedb(url)
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(1), DateTime(2))) == 4
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(2), DateTime(3))) == 5
        @test apero_time(country=country(:France), t=TimeSlice(DateTime(1), DateTime(3))) == 4.5
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
    call = Call(+, (3, 4))
    @test realize(call) == 7
    @test !is_varying(call)
    France = Object(:France)
    ts = TimeSeries([DateTime(0), DateTime(1)], [40, 70], false, false)
    country = ObjectClass(:country, [France], Dict(France => Dict(:apero_time => parameter_value(ts))))
    apero_time = Parameter(:apero_time, [country])
    call = apero_time[(; country=France, t=TimeSlice(DateTime(0), DateTime(1)))]
    @test realize(call) == 40
    @test is_varying(call)
    another_call = Call(*, (3, call))
    @test realize(another_call) == 120
    @test is_varying(another_call)
end
