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
end